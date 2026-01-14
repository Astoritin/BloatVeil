#!/system/bin/sh

MODS_DIR="/data/adb/modules"
[ -n "$(magisk -v | grep lite)" ] && MODS_DIR="/data/adb/lite_modules"

MOD_ID="bloat_veil"
MOD_DESC="A bloatware vanishing act on the system."
MOD_DIR="$MODS_DIR/$MOD_ID"

. "$MOD_DIR/wanderer.sh"

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
FLAG_BRICKED="$CONFIG_DIR/bricked"

TARGET_LIST="$CONFIG_DIR/targets.txt"
TARGET_LIST_BVA="$CONFIG_DIR/targets_bva.txt"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

MIRROR_DIR="$MOD_DIR/mirror"
MIRROR_SYSTEM_DIR="$MOD_DIR/system"

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
