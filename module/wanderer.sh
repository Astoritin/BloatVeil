#!/system/bin/sh
MODDIR=${0%/*}

is_magisk() {

    if ! command -v magisk >/dev/null 2>&1; then
        return 1
    fi

    MAGISK_V_VER_NAME="$(magisk -v)"
    MAGISK_V_VER_CODE="$(magisk -V)"
    case "$MAGISK_V_VER_NAME" in
        *"-alpha"*) MAGISK_BRANCH_NAME="Alpha" ;;
        *"-lite"*)  MAGISK_BRANCH_NAME="Magisk Lite" ;;
        *"-kitsune"*) MAGISK_BRANCH_NAME="Kitsune Mask" ;;
        *"-delta"*) MAGISK_BRANCH_NAME="Magisk Delta" ;;
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

    MAGISK_BRANCH_NAME="Official"
    ROOT_SOL="Magisk"
    ROOT_SOL_COUNT=0

    is_kernelsu && ROOT_SOL_COUNT=$((ROOT_SOL_COUNT + 1))
    is_apatch && ROOT_SOL_COUNT=$((ROOT_SOL_COUNT + 1))
    is_magisk && ROOT_SOL_COUNT=$((ROOT_SOL_COUNT + 1))

    if [ "$DETECT_KSU" = "true" ]; then
        ROOT_SOL="KernelSU"
        ROOT_SOL_DETAIL="KernelSU (kernel:$KSU_KERNEL_VER_CODE, ksud:$KSU_VER_CODE)"
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

	if [ $# -eq 0 ]; then
		ecov "No directories specified to initialize"
		return 1
	fi

    for dir_to_init in "$@"; do
		if [ -z "$dir_to_init" ]; then
			ecov "Directory to initialize is empty, skipping"
			continue
		fi
		if [ ! -d "$dir_to_init" ]; then
			mkdir -p "$dir_to_init"
			result_mkdir=$?
			ecov "Creating directory: $dir_to_init ($result_mkdir)"
		fi
	done

}

clean_dir_if_reach_max() {
    dir_to_clean="$1"
    files_max="$2"
    
    if [ -z "$dir_to_clean" ] || [ ! -d "$dir_to_clean" ]; then
		ecov "Directory to clean is not defined or does not exist"
		return 1
	elif [ -z "$files_max" ]; then
		ecov "Maximum files limit is not defined, using default value 20"
		files_max=20
	fi

    files_count=$(ls -1 "$dir_to_clean" | wc -l)
	ecov "Files in $dir_to_clean: $files_count, Max allowed: $files_max"
    if [ "$files_count" -gt "$files_max" ]; then
		ecov "Cleaning files in $dir_to_clean"
        find "$dir_to_clean" -maxdepth 1 -type f -exec rm -f {} +
    fi
    return 0
}

get_tid() {
    { cat /proc/self/stat | awk '{print $4}'; } 2>/dev/null || echo "$$"
}

eco() {
    _eco_level="${1:-i}"
    _eco_msg="$2"
    _eco_tag="${3:-$MOD_NAME}"
    _eco_pid="$$"
    _eco_tid="$(get_tid)"
    _eco_timestamp=$(date '+%m-%d %H:%M:%S.000')

    [ -z "$_eco_msg" ] && return 1

    case "$_eco_level" in
        [dD]*) _eco_level="D" ;;
        [iI]*) _eco_level="I" ;;
        [wW]*) _eco_level="W" ;;
        [eE]*) _eco_level="E" ;;
        [vV]*) _eco_level="V" ;;
        [fF]*) _eco_level="F" ;;
        *) _eco_level="I" ;;
    esac
    
    if command -v log >/dev/null 2>&1; then
        log -p "$_eco_level" -t "$_eco_tag" "$_eco_msg"
    fi
    
    echo "${_eco_timestamp}  ${_eco_pid}  ${_eco_tid} ${_eco_level} ${_eco_tag}: ${_eco_msg}" >> "$LOG_FILE" 2>/dev/null

}

ecoi() { eco "I" "$1" ; }
ecod() { eco "D" "$1" ; }
ecow() { eco "W" "$1" ; }
ecoe() { eco "E" "$1" ; }
ecof() { eco "F" "$1" ; }
ecov() { eco "V" "$1" ; }

print_line() {

    length=${1:-39}
    symbol=${2:--}

    line=$(printf "%-${length}s" | tr ' ' "$symbol")
    echo "$line"

}

grep_config_var() {
    regex="s/^$1=//p"
    config_file="$2"

    [ -z "$config_file" ] && config_file="/system/build.prop"
    cat "$config_file" 2>/dev/null | dos2unix | sed -n "$regex" | head -n 1

}

get_config_var() {
    key=$1
    config_file=$2

    if [ -z "$key" ] || [ -z "$config_file" ]; then
        ecow "Key or config file path is not defined"
        return 1
    elif [ ! -f "$config_file" ]; then
        ecow "$config_file is not a file"
        return 2
    fi
    
    value=$(awk -v key="$key" '
        BEGIN {
            key_regex = "^" key "="
            found = 0
            in_quote = 0
            value = ""
        }
        $0 ~ key_regex && !found {
            sub(key_regex, "")
            remaining = $0

            sub(/^[[:space:]]*/, "", remaining)

            if (remaining ~ /^"/) {
                in_quote = 1
                remaining = substr(remaining, 2)

                if (match(remaining, /"([[:space:]]*)$/)) {
                    value = substr(remaining, 1, RSTART - 1)
                    in_quote = 0
                } else {
                    value = remaining
                    while ((getline remaining) > 0) {
                        if (match(remaining, /"([[:space:]]*)$/)) {
                            line_part = substr(remaining, 1, RSTART - 1)
                            value = value "\n" line_part
                            in_quote = 0
                            break
                        } else {
                            value = value "\n" remaining
                        }
                    }
                    if (in_quote) exit 1
                }
                found = 1
            } else {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", remaining)
                value = remaining
                found = 1
            }
            if (found) exit 0
        }
        END {
            if (!found) exit 1
            gsub(/[[:space:]]+$/, "", value)
            print value
        }
    ' "$config_file")

    awk_exit_state=$?
    case $awk_exit_state in
        1)  ecow "Failed to fetch value for $key (1)"
            return 5
            ;;
        0)  ;;
        *)  ecow "Unexpected error ($awk_exit_state)"
            return 6
            ;;
    esac

    value=$(echo "$value" | dos2unix | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/'\''/'\\\\'\'''\''/g' | sed 's/[$;&|<>`"()]/\\&/g')

    if [ -n "$value" ]; then
        echo "$value"
        return 0
    else
        ecow "Key $key does not exist in file $config_file"
        return 1
    fi
}

update_config_var() {
    key_name="$1"
    file_path="$2"
    expected_value="$3"
    append_mode="${4:-false}"

    if [ -z "$key_name" ] || [ -z "$expected_value" ] || [ -z "$file_path" ]; then
		ecov "Key name, expected value, or file path is not defined"
        return 1
    elif [ ! -f "$file_path" ]; then
		ecov "$file_path is not a file"
        return 2
    fi

    if grep -q "^${key_name}=" "$file_path"; then
		ecov "Key $key_name exists in $file_path"
        if [ "$append_mode" = true ]; then
			ecov "Append mode enabled, will not update value"
			return 0
		fi
        sed -i "/^${key_name}=/c\\${key_name}=${expected_value}" "$file_path"
    else
		ecov "Key $key_name does not exist in $file_path, adding it"
        [ -n "$(tail -c1 "$file_path")" ] && echo >> "$file_path"
        printf '%s=%s\n' "$key_name" "$expected_value" >> "$file_path"
    fi

    result_update_value=$?
    return "$result_update_value"
}

remove_config_var() {
    key_name="$1"
    file_path="$2"

    if [ -z "$key_name" ] || [ -z "$file_path" ]; then
		ecov "Key name or file path is not defined"
        return 1
    elif [ ! -f "$file_path" ]; then
		ecov "$file_path is not a file"
        return 2
    fi

    sed -i "/^${key_name}=/d" "$file_path"
    return "$?"
}

query_var() {

    for var_name in "$@"; do
        eval printf '%s=%s\\n' "$var_name" \"\$$var_name\"
    done

}

print_var() {

    [ $# -eq 0 ] && return 1

    query_var "$@" | while IFS= read -r line || [ -n "$line" ]; do
        echo "- $line"
    done

}

show_system_info() {

    echo "- Device: $(getprop ro.product.brand) $(getprop ro.product.model) ($(getprop ro.product.device))"
    echo "- OS: Android $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk)), $(getprop ro.product.cpu.abi | cut -d '-' -f1)"
    echo "- Kernel: $(uname -r)"

}

module_intro() {

    MODULE_PROP="$MODDIR/module.prop"
    MOD_NAME="$(grep_config_var "name" "$MODULE_PROP")"
    MOD_AUTHOR="$(grep_config_var "author" "$MODULE_PROP")"
    MOD_VER="$(grep_config_var "version" "$MODULE_PROP") ($(grep_config_var "versionCode" "$MODULE_PROP"))"

    install_env_check
    print_line
    echo "- $MOD_NAME"
    echo "- By $MOD_AUTHOR"
    echo "- Version: $MOD_VER"
    echo "- Root: $ROOT_SOL_DETAIL"
    print_line

}

file_compare() {
    file_a="$1"
    file_b="$2"
	
	if [ -z "$file_a" ] || [ -z "$file_b" ]; then
		ecov "File A or File B path is not defined"
		return 2
	elif [ ! -f "$file_a" ]; then
		ecov "$file_a is not a file"
		return 3
	elif [ ! -f "$file_b" ]; then
		ecov "$file_b is not a file"
		return 3
	fi
    
    hash_file_a=$(sha256sum "$file_a" | awk '{print $1}')
    hash_file_b=$(sha256sum "$file_b" | awk '{print $1}')

	ecov "Hash of file A: $hash_file_a"
	ecov "Hash of file B: $hash_file_b"
    
    if [ "$hash_file_a" = "$hash_file_b" ]; then
		ecov "Files are identical"
		return 0
	else
		ecov "Files are different"
		return 1
	fi

}

check_duplicate_items() {

    itemd=$1
    filed=$2

	if [ -z "$itemd" ] || [ -z "$filed" ]; then
		ecov "Item or file path is not defined"
		return 1
	elif [ ! -f "$filed" ]; then
		ecov "$filed is not a file"
		return 2
	fi

    if grep -q "^$itemd$" "$filed"; then
		ecov "Duplicate item $itemd found in $filed"
        return 1
    else
		ecov "No duplicate item $itemd found in $filed"
        return 0
    fi
}

clean_duplicate_items() {

    filed=$1

    if [ -z "$filed" ]; then
		ecov "File path is not defined"
		return 1
	elif [ ! -f "$filed" ];
		ecov "$filed is not a file"
		return 2
	fi

    awk '!seen[$0]++' "$filed" > "${filed}.tmp"
    mv "${filed}.tmp" "$filed"
    return 0

}
