#!/system/bin/sh

MODS_DIR="/data/adb/modules"
[ -n "$(magisk -v | grep lite)" ] && MODS_DIR="/data/adb/lite_modules"

MOD_NAME="bloat_veil"
MOD_DESC="A bloatware vanishing act on the system."
MOD_DIR="$MODS_DIR/$MOD_NAME"

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
FLAG_BRICKED="$CONFIG_DIR/bricked"

TARGET_LIST="$CONFIG_DIR/targets.txt"
TARGET_LIST_BVA="$CONFIG_DIR/targets_bva.txt"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"


. "$MOD_DIR/wanderer.sh"

brick_rescue=$(get_key_value "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
brick_and_disable=$(get_key_value "brick_and_disable" "$CONFIG_FILE") || brick_and_disable=true
last_worked_target_list=$(get_key_value "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true

if [ "$brick_rescue" = false ]; then

fi


if [ -f "$FLAG_BRICKED" ]; then
    if [ -f "$MOD_DIR/disable" ]; then
        if [ "$last_worked_target_list" = "true" ]; then
            if [ -f "$TARGET_LIST_LW" ]; then
                cp "$TARGET_LIST_LW" "$TARGET_LIST"
                rm -f "$MOD_DIR/disable"
                rm -f "$FLAG_BRICKED"
                return 0
            fi

        fi
    fi
    update_key_value "description" "$MOD_DIR/module.prop" "$MOD_DESC"
fi

    

rm -f "$MOD_DIR/mirror" "$MOD_DIR/system"
rm -f "$TARGET_LIST_BVA"
rm -f "/data/adb/post-fs-data.d/cleanup_bloat_veil.sh"
