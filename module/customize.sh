#!/system/bin/sh
SKIPUNZIP=1

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/targets.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TEMPLATE_FILE="$LAST_WORKED_DIR/targets_tm.txt"

MOD_PROP="${TMPDIR}/module.prop"
MOD_NAME="$(grep_prop name "$MOD_PROP")"
MOD_VER="$(grep_prop version "$MOD_PROP") ($(grep_prop versionCode "$MOD_PROP"))"
MOD_DESC="A bloatware vanishing act on system."

POST_D="/data/adb/post-fs-data.d/"
CLEANUP_SH="bloat_veil_unbrick.sh"
CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

MIN_VER_KERNELSU_SUPPORT_MOUNTING=22098

UPDATE_ONLINE=false

extract() {
    file="$1"
    dir="${2:-$MODPATH}"
    junk="${3:-false}"
    opts="-o"

    file_path="$dir/$file"  
    hash_path="$TMPDIR/$file.sha256"

    if [ "$junk" = true ]; then
        opts="-oj"
        file_path="$dir/$(basename "$file")"
        hash_path="$TMPDIR/$(basename "$file").sha256"
    fi

    file_dir="$(dirname $file_path)"
    mkdir -p "$file_dir" || abort "! Failed to create dir $dir!"

    unzip $opts "$ZIPFILE" "$file" -d "$dir" >&2
    [ -f "$file_path" ] || abort "! $file does NOT exist"

    unzip $opts "$ZIPFILE" "${file}.sha256" -d "$TMPDIR" >&2
    [ -f "$hash_path" ] || abort "! ${file}.sha256 does NOT exist"

    expected_hash="$(cat "$hash_path")"
    calculated_hash="$(sha256sum "$file_path" | cut -d ' ' -f1)"

    if [ "$expected_hash" == "$calculated_hash" ]; then
        ui_print "- Verified $file" >&1
    else
        abort "! Failed to verify $file"
    fi
}

metamodule_required() {

    if [ "$KSU_KERNEL_VER_CODE" -ge "$MIN_VER_KERNELSU_SUPPORT_MOUNTING" ]; then
        ui_print "- Current KernelSU requires"
        ui_print "- metamodule for mounting"
        ui_print "- Scanning metamodule"
        checkout_modules_dir
        if ! checkout_meta_module; then
            ui_print "- You haven't installed any metamodule!"
            ui_print "- Only Mount Bind mode is available on KernelSU"
        else
            ui_print "- Current metamodule: ${current_module_name} ${current_module_ver_name} (${current_module_ver_code})"
        fi
    fi

}


extract "wanderer.sh" "$TMPDIR" >/dev/null 2>&1
. "$TMPDIR/wanderer.sh"

ui_print "- Setting up $MOD_NAME"
ui_print "- Version: $MOD_VER"
install_env_check
init_dir "$LAST_WORKED_DIR" "$POST_D"
unzip -o "$ZIPFILE" "META-INF/com/google/android/*" -d "$TMPDIR" >/dev/null 2>&1
[ -f "$TMPDIR/META-INF/com/google/android/update-binary.sha256" ] && extract "META-INF/com/google/android/update-binary" "$TMPDIR" >/dev/null 2>&1 && UPDATE_ONLINE=false
[ -f "$TMPDIR/META-INF/com/google/android/updater-script.sha256" ] && extract "META-INF/com/google/android/updater-script" "$TMPDIR" >/dev/null 2>&1 && UPDATE_ONLINE=false
if [ "$UPDATE_ONLINE" = true ]; then
    ui_print "- Updating from $ROOT_SOL app"
else
    ui_print "- Installing from $ROOT_SOL app"
fi
ui_print "- Root: $ROOT_SOL_DETAIL"
[ "$DETECT_KSU" = true ] && metamodule_required
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
extract "targets.txt" "$TMPDIR"
cat "$TMPDIR/targets.txt" > "$TEMPLATE_FILE"
rm -f "/data/adb/post-fs-data.d/cleanup_bloat_veil.sh" >/dev/null 2>&1
[ ! -f "$TARGET_LIST" ] && cat "$TMPDIR/targets.txt" > "$TARGET_LIST"
[ ! -f "$CONFIG_FILE" ] && extract "settings.conf" "$CONFIG_DIR"
DESCRIPTION="[⚠️Check $TARGET_LIST carefully before reboot!] ${MOD_DESC}"
update_key_value "description" "$MODPATH/module.prop" "$DESCRIPTION"
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644
ui_print "- Welcome to $MOD_NAME!"