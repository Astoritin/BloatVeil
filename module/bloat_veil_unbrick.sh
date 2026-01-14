#!/system/bin/sh

MODS_DIR="/data/adb/modules"
[ -n "$(magisk -v | grep lite)" ] && MODS_DIR="/data/adb/lite_modules"

MOD_ID="bloat_veil"
MOD_DESC="A bloatware vanishing act on system."
MOD_DIR="$MODS_DIR/$MOD_ID"

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
FLAG_BRICKED="$CONFIG_DIR/bricked"

TARGET_LIST="$CONFIG_DIR/targets.txt"
TARGET_LIST_BVA="$CONFIG_DIR/targets_bva.txt"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

MIRROR_DIR="$MOD_DIR/mirror"
MIRROR_SYSTEM_DIR="$MOD_DIR/system"

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

update_key_value() {
    local key="$1"
    local conf="$2"
    local expected="$3"
    local append="${4:-false}"

    [ -z "$key" ] || [ -z "$expected" ] || [ -z "$conf" ] || [ ! -f "$conf" ] && return 1

    if grep -q "^${key}=" "$conf"; then
        [ "$append" = true ] && return 0
        sed -i "/^${key}=/c\\${key}=${expected}" "$conf"
    else
        [ -n "$(tail -c1 "$conf")" ] && echo >> "$conf"
        printf '%s=%s\n' "$key" "$expected" >> "$conf"
    fi
}

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

    [ "$brick_rescue" = false ] && return
    [ ! -f "$FLAG_BRICKED" ] && return
    [ "$brick_and_disable" = "true" ] && [ ! -f "$MOD_DIR/disable" ] && return
    [ "$last_worked_target_list" != "true" ] && return
    [ ! -f "$TARGET_LIST_LW" ] && return

    if file_compare "$TARGET_LIST_LW" "$TARGET_LIST"; then
        rm -f "$TARGET_LIST_LW"
        return
    fi
    cp "$TARGET_LIST_LW" "$TARGET_LIST"
    [ "$brick_and_disable" = "true" ] && rm -f "$MOD_DIR/disable"
    rm -f "$FLAG_BRICKED"

}

config_loader
unbrick
update_key_value "description" "$MOD_DIR/module.prop" "$MOD_DESC"

[ -d "$MIRROR_DIR" ] && rm -rf "$MIRROR_DIR"
[ -d "$MIRROR_SYSTEM_DIR" ] && rm -rf "$MIRROR_SYSTEM_DIR"
rm -f "$TARGET_LIST_BVA"
rm -f "/data/adb/post-fs-data.d/bloat_veil_unbrick.sh"
