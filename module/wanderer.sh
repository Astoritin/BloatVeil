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
    dir_to_clean="$1"
    files_max="$2"
    
    [ -z "$dir_to_clean" ] || [ ! -d "$dir_to_clean" ] && return 1
	[ -z "$files_max" ] && files_max=20

    files_count=$(ls -1 "$dir_to_clean" | wc -l)
    if [ "$files_count" -gt "$files_max" ]; then
        find "$dir_to_clean" -maxdepth 1 -type f -exec rm -f {} +
    fi
}

eco() { echo "$1" >> "$LOG_FILE" 2>/dev/null; }
ecoe() { echo " " >> "$LOG_FILE" 2>/dev/null; }

ecol() {

    length=64
    symbol=-

    line=$(printf "%-${length}s" | tr ' ' "$symbol")
    echo "$line" >> "$LOG_FILE" 2>/dev/null

}

get_config_var() {
    key=$1
    config_file=$2
    [ -n "$key" ] && [ -f "$config_file" ] || return 1

    awk -v key="$key" '
        BEGIN {
            key_regex = "^" key "="
            found = 0; in_quote = 0; val = ""
        }
        !found && $0 ~ key_regex {
            sub(key_regex, "")
            sub(/^[[:space:]]*/, "")
            if (sub(/^"/, "")) {
                in_quote = 1
                if (sub(/"[[:space:]]*$/, "")) {
                    val = $0
                    in_quote = 0
                } else {
                    val = $0
                    while ((getline line) > 0) {
                        if (sub(/"[[:space:]]*$/, "", line)) {
                            val = val "\n" line
                            in_quote = 0
                            break
                        } else {
                            val = val "\n" line
                        }
                    }
                    if (in_quote) exit 1
                }
                found = 1
            } else {
                val = $0
                sub(/[[:space:]]+$/, "", val)
                found = 1
            }
            if (found) exit 0
        }
        END {
            if (!found) exit 1
            print val
        }
    ' "$config_file" | tr -d '\r'

    [ $? -eq 0 ] || return 1
}

update_config_var() {
    key_name="$1"
    file_path="$2"
    expected_value="$3"
    append_mode="${4:-false}"

    if [ -z "$key_name" ] || [ -z "$expected_value" ] || [ -z "$file_path" ]; then
        return 1
    elif [ ! -f "$file_path" ]; then
        return 2
    fi

    if grep -q "^${key_name}=" "$file_path"; then
        [ "$append_mode" = true ] && return 0
        sed -i "/^${key_name}=/c\\${key_name}=${expected_value}" "$file_path"
    else
        [ -n "$(tail -c1 "$file_path")" ] && echo >> "$file_path"
        printf '%s=%s\n' "$key_name" "$expected_value" >> "$file_path"
    fi
}

remove_config_var() {
    key_name="$1"
    file_path="$2"

    if [ -z "$key_name" ] || [ -z "$file_path" ]; then
        return 1
    elif [ ! -f "$file_path" ]; then
        return 2
    fi

    sed -i "/^${key_name}=/d" "$file_path"
}

query_var() {

    for var_name in "$@"; do
        eval printf '%s=%s\\n' "$var_name" \"\$$var_name\"
    done

}

print_var() {

    [ $# -eq 0 ] && return 1

    query_var "$@" | while IFS= read -r line || [ -n "$line" ]; do
        eco "$line"
    done

}

show_system_info() {

    eco "$(getprop ro.product.brand) $(getprop ro.product.model) ($(getprop ro.product.device))"
    eco "Android $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk)), $(getprop ro.product.cpu.abi | cut -d '-' -f1)"
    eco "Kernel: $(uname -r)"

}

module_intro() {

    MODULE_PROP="$MODDIR/module.prop"
    MOD_NAME="$(get_config_var "name" "$MODULE_PROP")"
    MOD_AUTHOR="$(get_config_var "author" "$MODULE_PROP")"
    MOD_VER="$(get_config_var "version" "$MODULE_PROP") ($(get_config_var "versionCode" "$MODULE_PROP"))"

    install_env_check
    eco "$MOD_NAME"
    eco "By $MOD_AUTHOR"
    eco "Version: $MOD_VER"
    eco "Root: $ROOT_SOL_DETAIL"
    ecoe

}

checkout_metamodule() {
    modules_dir="/data/adb/modules"
    modules_update_dir="/data/adb/modules_update"

    for moddir in "$modules_dir" "$modules_update_dir"; do
        [ -d "$moddir" ] || continue
        for current_module_dir in "$moddir"/*; do
            current_module_prop="$current_module_dir/module.prop"
            [ -e "$current_module_prop" ] || continue

            is_metamodule=$(get_config_var "metamodule" "$current_module_prop")
            current_module_name=$(get_config_var "name" "$current_module_prop")
            current_module_ver_name=$(get_config_var "version" "$current_module_prop")
            current_module_ver_code=$(get_config_var "versionCode" "$current_module_prop")
            case "$is_metamodule" in
                1|true ) [ ! -f "$current_module_dir/disable" ] && [ ! -f "$current_module_dir/remove" ] && return 0;;
            esac

        done
    done
    return 1
}

file_compare() {
    file_a="$1"
    file_b="$2"
    
    [ -z "$file_a" ] || [ ! -f "$file_a" ] && return 2
    [ -z "$file_b" ] || [ ! -f "$file_b" ] && return 3
    
    hash_file_a=$(sha256sum "$file_a" | awk '{print $1}')
    hash_file_b=$(sha256sum "$file_b" | awk '{print $1}')
    
    [ "$hash_file_a" = "$hash_file_b" ] && return 0
    [ "$hash_file_a" != "$hash_file_b" ] && return 1
}

check_duplicate_items() {
    itemd=$1
    filed=$2

    if grep -q "^$itemd$" "$filed"; then
        return 1
    else
        return 0
    fi
}

clean_duplicate_items() {
    filed=$1

    [ -z "$filed" ] && return 1
    [ ! -f "$filed" ] && return 2

    awk '!seen[$0]++' "$filed" > "${filed}.tmp"
    mv "${filed}.tmp" "$filed"
}
