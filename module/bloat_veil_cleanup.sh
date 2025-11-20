#!/system/bin/sh

DESCRIPTION="A bloatware vanishing act on the system."

CONFIG_DIR="/data/adb/bloat_veil"

LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/bv_1_$(date +"%Y%m%dT%H%M%S").log"

FLAG_BRICKED="$CONFIG_DIR/bricked"

POST_D="/data/adb/post-fs-data.d/"
CLEANUP_SH="bloat_veil_cleanup.sh"
CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

MOD_DIR="/data/adb/modules/bloat_veil"
LITE_MOD_DIR="/data/adb/lite_modules/bloat_veil"

. "${MOD_DIR}/wanderer.sh"

init_dir "$TEMPLATE_DIR" "$LOG_DIR"
module_intro >> "$LOG_FILE"
show_system_info >> "$LOG_FILE"
print_line

if [ ! -f "$FLAG_BRICKED" ]; then
	ecov "Module not marked as bricked, skipping cleanup"
    if [ -f "$MOD_DIR/disable" ]; then
		ecov "Updating description in module.prop of $MOD_DIR"
        update_config_var "description" "$MOD_DIR/module.prop" "$DESCRIPTION"
    elif [ -f "$LITE_MOD_DIR/disable" ]; then
		ecov "Updating description in module.prop of $LITE_MOD_DIR"
        update_config_var "description" "$LITE_MOD_DIR/module.prop" "$DESCRIPTION"
    fi
fi

rm -f "${CLEANUP_PATH}" && ecov "Removed cleanup script at ${CLEANUP_PATH}"
