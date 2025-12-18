#!/system/bin/sh

DESCRIPTION="A bloatware vanishing act on the system."

CONFIG_DIR="/data/adb/bloat_veil"
LOG_DIR="$CONFIG_DIR/logs"
TARGET_LIST_BVA="$LOG_DIR/targets_bva.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

POST_D="/data/adb/post-fs-data.d/"
CLEANUP_SH="cleanup_bloat_veil.sh"
CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

MODDIR="/data/adb/modules/bloat_veil"
MIRROR_DIR="$MODDIR/mirror"
MIRROR_SYSTEM_DIR="$MODDIR/system"

. "$MODDIR/wanderer.sh"

if [ ! -f "$FLAG_BRICKED" ]; then
    if [ -f "$MODDIR/disable" ]; then
        update_config_var "description" "$MODDIR/module.prop" "$DESCRIPTION"
    fi
fi

rm -f "${TARGET_LIST_BVA}"
rm -f "${MIRROR_DIR}"
rm -f "${MIRROR_SYSTEM_DIR}"
rm -f "${CLEANUP_PATH}"
