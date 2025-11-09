#!/system/bin/sh
SKIPUNZIP=1

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/target.txt"
LOG_DIR="$CONFIG_DIR/logs"

MOD_PROP="${TMPDIR}/module.prop"
MOD_NAME="$(grep_prop name "$MOD_PROP")"
MOD_VER="$(grep_prop version "$MOD_PROP") ($(grep_prop versionCode "$MOD_PROP"))"
MOD_INTRO="A bloatware vanishing act on the system."

POST_D="/data/adb/post-fs-data.d/"
CLEANUP_SH="bloat_veil_cleanup.sh"
CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

unzip -o "$ZIPFILE" "wanderer.sh" -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/wanderer.sh" ]; then
    ui_print "! Failed to extract wanderer.sh!"
    abort "! This zip may be corrupted!"
fi

. "$TMPDIR/wanderer.sh"

eco "Setting up $MOD_NAME"
eco "Version: $MOD_VER"
eco_init "$LOG_DIR"
show_system_info
install_env_check
eco "Installing from $ROOT_SOL app"
extract "customize.sh" "$TMPDIR"
extract "module.prop"
extract "wanderer.sh"
extract "post-fs-data.sh"
extract "service.sh"
extract "$CLEANUP_SH"
cat "$MODPATH/$CLEANUP_SH" > "$CLEANUP_PATH"
chmod +x "$CLEANUP_PATH"
extract "action.sh"
extract "uninstall.sh"
[ ! -f "$CONFIG_FILE" ] && extract "settings.conf" "$CONFIG_DIR"
[ ! -f "$TARGET_LIST" ] && extract "target.txt" "$CONFIG_DIR"
DESCRIPTION="[📌Check $TARGET_LIST carefully before reboot! Powered by ${ROOT_SOL_DETAIL}] $MOD_INTRO"
update_config_var "description" "$MODPATH/module.prop" "$DESCRIPTION"
eco "Setting permission"
set_perm_recursive "$MODPATH" 0 0 0755 0644
eco "Welcome to use $MOD_NAME!"