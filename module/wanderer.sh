is_magisk() {

    if ! command -v magisk >/dev/null 2>&1; then
        return 1
    fi

    MAGISK_V_VER_NAME="$(magisk -v)"
    MAGISK_V_VER_CODE="$(magisk -V)"
    case "$MAGISK_V_VER_NAME" in
        *"-alpha"*) MAGISK_BRANCH_NAME="Alpha" ;;
        *) MAGISK_BRANCH_NAME="Magisk" ;;
    esac
    DETECT_MAGISK="true"
    return 0

}

is_kernelsu() {
    if [ -n "$KSU" ]; then
        DETECT_KSU="true"
        ROOT_SOL="KernelSU"
        return 0
    fi
    return 1
}

is_apatch() {
    if [ -n "$APATCH" ]; then
        DETECT_APATCH="true"
        ROOT_SOL="APatch"
        return 0
    fi
    return 1
}

install_env_check() {

    ROOT_SOL="Magisk"
    ROOT_SOL_COUNT=0

    is_kernelsu && ROOT_SOL_COUNT=$((ROOT_SOL_COUNT + 1))
    is_apatch && ROOT_SOL_COUNT=$((ROOT_SOL_COUNT + 1))
    is_magisk && ROOT_SOL_COUNT=$((ROOT_SOL_COUNT + 1))

    if [ "$DETECT_KSU" = "true" ]; then
        ROOT_SOL="KernelSU"
        ROOT_SOL_DETAIL="KernelSU ($KSU_KERNEL_VER_CODE)"
    elif [ "$DETECT_APATCH" = "true" ]; then
        ROOT_SOL="APatch"
        ROOT_SOL_DETAIL="APatch ($APATCH_VER_CODE)"
    elif [ "$DETECT_MAGISK" = "true" ]; then
        ROOT_SOL="Magisk"
        ROOT_SOL_DETAIL="$MAGISK_BRANCH_NAME (${MAGISK_VER_CODE:-$MAGISK_V_VER_CODE})"
    fi

    if [ "$ROOT_SOL_COUNT" -gt 1 ]; then
        ROOT_SOL="Multiple"
        ROOT_SOL_DETAIL="Multiple"
    elif [ "$ROOT_SOL_COUNT" -lt 1 ]; then
        ROOT_SOL="Unknown"
        ROOT_SOL_DETAIL="Unknown"
    fi

}

init_dir() {
	[ $# -eq 0 ] && return 1

    for dir_to_init in "$@"; do
		[ -z "$dir_to_init" ] && continue
		[ ! -d "$dir_to_init" ] && mkdir -p "$dir_to_init"
	done
}

clean_dir_if_reach_max() {
    local dir_to_clean="$1"
    local files_max="$2"
    
    [ -z "$dir_to_clean" ] || [ ! -d "$dir_to_clean" ] && return 1
	[ -z "$files_max" ] && files_max=20

    files_count=$(ls -1 "$dir_to_clean" | wc -l)
    if [ "$files_count" -gt "$files_max" ]; then
        find "$dir_to_clean" -maxdepth 1 -type f -exec rm -f {} +
    fi
}

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

remove_config_var() {
    local key="$1"
    local conf="$2"

    [ -z "$key" ] || [ -z "$conf" ] || [ ! -f "$conf" ] && return 1
    sed -i "/^${key}=/d" "$conf"
}

module_intro() {

    MODULE_PROP="$MODDIR/module.prop"
    MOD_NAME="$(get_key_value "name" "$MODULE_PROP")"
    MOD_AUTHOR="$(get_key_value "author" "$MODULE_PROP")"
    MOD_VER="$(get_key_value "version" "$MODULE_PROP") ($(get_key_value "versionCode" "$MODULE_PROP"))"
    install_env_check

}

checkout_metamodule() {
    modules_dir="/data/adb/modules"
    modules_update_dir="/data/adb/modules_update"

    for moddir in "$modules_dir" "$modules_update_dir"; do
        [ -d "$moddir" ] || continue
        for current_module_dir in "$moddir"/*; do
            current_module_prop="$current_module_dir/module.prop"
            [ -e "$current_module_prop" ] || continue

            is_metamodule=$(get_key_value "metamodule" "$current_module_prop")
            current_module_name=$(get_key_value "name" "$current_module_prop")
            current_module_ver_name=$(get_key_value "version" "$current_module_prop")
            current_module_ver_code=$(get_key_value "versionCode" "$current_module_prop")
            case "$is_metamodule" in
                1|true ) [ ! -f "$current_module_dir/disable" ] && [ ! -f "$current_module_dir/remove" ] && return 0;;
            esac

        done
    done
    return 1
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

check_duplicate_items() {
    local itemd=$1
    local filed=$2

    if grep -q "^$itemd$" "$filed"; then
        return 1
    else
        return 0
    fi
}

clean_duplicate_items() {
    local filed=$1

    [ -z "$filed" ] && return 1
    [ ! -f "$filed" ] && return 2

    awk '!seen[$0]++' "$filed" > "${filed}.tmp"
    mv "${filed}.tmp" "$filed"
}
