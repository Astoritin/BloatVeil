#!/system/bin/sh

DESCRIPTION="A bloatware vanishing act on the system."

CONFIG_DIR="/data/adb/bloat_veil"
LOG_DIR="$CONFIG_DIR/logs"
TARGET_LIST_BVA="$LOG_DIR/targets_bva.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

POST_D="/data/adb/post-fs-data.d/"
CLEANUP_SH="cleanup_bloat_veil.sh"
CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

MOD_DIR="/data/adb/modules/bloat_veil"
LITE_MOD_DIR="/data/adb/lite_modules/bloat_veil"

. "$MOD_DIR/wanderer.sh"

if [ ! -f "$FLAG_BRICKED" ]; then
    if [ -f "$MOD_DIR/disable" ]; then
        update_config_var "description" "$MOD_DIR/module.prop" "$DESCRIPTION"
    elif [ -f "$LITE_MOD_DIR/disable" ]; then
        update_config_var "description" "$LITE_MOD_DIR/module.prop" "$DESCRIPTION"
    fi
fi

rm -f "${TARGET_LIST_BVA}"
rm -f "${CLEANUP_PATH}"
