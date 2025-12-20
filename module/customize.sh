#!/system/bin/sh
SKIPUNZIP=1

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/targets.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TEMPLATE_FILE="$LAST_WORKED_DIR/targets_tm.txt"

LOG_DIR="$CONFIG_DIR/logs"

MOD_PROP="${TMPDIR}/module.prop"
MOD_NAME="$(grep_prop name "$MOD_PROP")"
MOD_VER="$(grep_prop version "$MOD_PROP") ($(grep_prop versionCode "$MOD_PROP"))"
MOD_INTRO="A bloatware vanishing act on the system."

POST_D="/data/adb/post-fs-data.d/"
CLEANUP_SH="cleanup_bloat_veil.sh"
CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

MIN_VER_KERNELSU_SUPPORT_MOUNTING=22098

update_online=false

extract() {
    file=$1
    dir=$2
    junk=${3:-false}
    opts="-o"

    [ -z "$dir" ] && dir="$MODPATH"
    file_path="$dir/$file"
    hash_path="$TMPDIR/$file.sha256"

    if [ "$junk" = true ]; then
        opts="-oj"
        file_path="$dir/$(basename "$file")"
        hash_path="$TMPDIR/$(basename "$file").sha256"
    fi

    unzip $opts "$ZIPFILE" "$file" -d "$dir" >&2
    [ -f "$file_path" ] || abort "! $file does not exist"

    unzip $opts "$ZIPFILE" "${file}.sha256" -d "$TMPDIR" >&2
    [ -f "$hash_path" ] || abort "! ${file}.sha256 does not exist"

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
        ui_print "- Current KernelSU version requires metamodule"
        ui_print "- for mounting file(s) on /system"
        ui_print "- Scanning metamodule"
        if ! checkout_metamodule; then
            ui_print "- You haven't installed any metamodule!"
            ui_print "- Only Mount Bind mode is available on KernelSU"
        else
            ui_print "- Current metamodule: ${current_module_name} ${current_module_ver_name} (${current_module_ver_code})"
        fi
    fi

}


extract "wanderer.sh" "$TMPDIR" >/dev/null 2>&1
. "$TMPDIR/wanderer.sh"

show_system_info() {

    ui_print "- Device: $(getprop ro.product.brand) $(getprop ro.product.model) ($(getprop ro.product.device))"
    ui_print "- OS: Android $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk)), $(getprop ro.product.cpu.abi | cut -d '-' -f1)"
    ui_print "- Kernel: $(uname -r)"

}

install_env_check
ui_print "- Installing from $ROOT_SOL app"
ui_print "- Root: $ROOT_SOL_DETAIL"
[ "$DETECT_KSU" = true ] && metamodule_required
ui_print "- Setting up $MOD_NAME"
ui_print "- Version: $MOD_VER"
init_dir "$LAST_WORKED_DIR" "$LOG_DIR" "$POST_D"
show_system_info
unzip -o "$ZIPFILE" "META-INF/com/google/android/*" -d "$TMPDIR" >/dev/null 2>&1
[ -f "$TMPDIR/META-INF/com/google/android/update-binary.sha256" ] && extract "META-INF/com/google/android/update-binary" "$TMPDIR" && update_online=false
[ -f "$TMPDIR/META-INF/com/google/android/updater-script.sha256" ] && extract "META-INF/com/google/android/updater-script" "$TMPDIR" && update_online=false
[ "$update_online" = true ] && ui_print "- Updating online"
[ "$update_online" = false ] && ui_print "- Updating offline"
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
[ ! -f "$TARGET_LIST" ] && cat "$TMPDIR/targets.txt" > "$TARGET_LIST"
[ ! -f "$CONFIG_FILE" ] && extract "settings.conf" "$CONFIG_DIR"
DESCRIPTION="[⚠️Check $TARGET_LIST carefully before reboot! ✅${ROOT_SOL_DETAIL}] ${MOD_INTRO}"
update_config_var "description" "$MODPATH/module.prop" "$DESCRIPTION"
ui_print "- Setting permission"
set_perm_recursive "$MODPATH" 0 0 0755 0644
ui_print "- Welcome to $MOD_NAME!"