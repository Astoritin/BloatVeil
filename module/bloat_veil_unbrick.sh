#!/system/bin/sh

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
FLAG_BRICKED="$CONFIG_DIR/bricked"

TARGET_LIST="$CONFIG_DIR/targets.txt"
TARGET_LIST_BVA="$CONFIG_DIR/targets_bva.txt"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

CURRRNT_MODULES_DIR="/data/adb/modules"
[ -n "$(magisk -v | grep lite)" ] >/dev/null 2>&1 && CURRRNT_MODULES_DIR="/data/adb/lite_modules"

MODID="bloat_veil"
MODDESC="A bloatware vanishing act on system."
MODDIR="$CURRRNT_MODULES_DIR/$MODID"

MIRROR_DIR="$MODDIR/mirror"
MIRROR_SYSTEM_DIR="$MODDIR/system"

get_key_value() {
    local key=$1
    local conf=$2
    [ -n "$key" ] && [ -f "$conf" ] || return 1

    awk -v key="$key" '
        BEGIN { key_regex = "^" key "[[:space:]]*=" }
        $0 ~ key_regex {
            sub(key_regex, "")
            sub(/^[[:space:]]*/, "")
            if (sub(/^"/, "")) {
                if (!sub(/"[[:space:]]*$/, "")) exit 1
            } else {
                sub(/[[:space:]]+$/, "")
            }
            print
            exit 0
        }
        END { exit 1 }
    ' "$conf" | tr -d '\r'

    [ $? -eq 0 ] || return 1
}

update_description() { [ -n "$1" ] || return 1; sed -i "s/^description=.*/description=$1/" "$MODDIR/module.prop"; }

file_compare() {
    local file_a="$1"
    local file_b="$2"
    
    [ -z "$file_a" ] || [ ! -f "$file_a" ] && return 2
    [ -z "$file_b" ] || [ ! -f "$file_b" ] && return 3
    
    hash_file_a=$(sha256sum "$file_a" | awk '{print $1}')
    hash_file_b=$(sha256sum "$file_b" | awk '{print $1}')
    
    [ "$hash_file_a" = "$hash_file_b" ] && return 0
    [ "$hash_file_a" != "$hash_file_b" ] && return 1
}

config_loader() {

    brick_rescue=$(get_key_value "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    brick_and_disable=$(get_key_value "brick_and_disable" "$CONFIG_FILE") || brick_and_disable=true
    last_worked_target_list=$(get_key_value "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true

}

unbrick() {

    [ "$brick_rescue" = true ] || return
    [ -f "$FLAG_BRICKED" ] || return

    [ "$brick_and_disable" = true ] && [ ! -f "$MODDIR/disable" ] && rm -f "$FLAG_BRICKED"

    if [ "$last_worked_target_list" = true ]; then
        [ -f "$TARGET_LIST_LW" ] || return
        if file_compare "$TARGET_LIST_LW" "$TARGET_LIST"; then
            rm -f "$TARGET_LIST_LW"
            return
        fi
        cp "$TARGET_LIST_LW" "$TARGET_LIST"
        rm -f "$MODDIR/disable"
        rm -f "$FLAG_BRICKED"
    fi
    update_description "[❌Triggered brick rescue!] $MODDESC"
}

config_loader
update_description "$MODDESC"
unbrick

[ -d "$MIRROR_DIR" ] && rm -rf "$MIRROR_DIR"
[ -d "$MIRROR_SYSTEM_DIR" ] && rm -rf "$MIRROR_SYSTEM_DIR"
rm -f "$TARGET_LIST_BVA"
