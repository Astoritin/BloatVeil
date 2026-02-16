#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/wanderer.sh"

MOD_DESC="A bloatware vanishing act on system."

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/targets.txt"
TARGET_LIST_BVA="$CONFIG_DIR/targets_bva.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TEMPLATE_FILE="$LAST_WORKED_DIR/targets_tm.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

MODULE_PROP="$MODDIR/module.prop"

MN_SUPPORT=false
MR_SUPPORT=false
MIN_VER_MAGISK_SUPPORT_MAKENODE=28102
MIN_VER_KERNELSU_TRY_METAMODULE=22098
MIN_VER_APATCH_TRY_METAMODULE=11170

MIRROR_DIR="$MODDIR/mirror"
MIRROR_SYSTEM_DIR="$MODDIR/system"

unbrick() {
    
    [ "$brick_rescue" = true ] || return 1
    [ ! -f "$FLAG_BRICKED" ] || exit 1

}

config_loader() {

    brick_rescue=$(get_key_value "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    hide_mode=$(get_key_value "hide_mode" "$CONFIG_FILE") || hide_mode=MB
    system_app_paths="/system/app /system/preload /system/product/app /system/product/data-app /system/product/priv-app /system/product/overlay /system/priv-app /system/system_ext/app /system/system_ext/priv-app /system/vendor/app /system/vendor/priv-app /system/vendor/overlay"

}

preparation() {

    [ -d "$MIRROR_DIR" ] && rm -rf "$MIRROR_DIR"
    [ -d "$MIRROR_SYSTEM_DIR" ] && rm -rf "$MIRROR_SYSTEM_DIR"

    if [ "$DETECT_KSU" = true ] || [ "$DETECT_APATCH" = true ]; then
        MN_SUPPORT=true
        checkout_modules_dir
        if [ "$KSU_KERNEL_VER_CODE" -ge "$MIN_VER_KERNELSU_TRY_METAMODULE" ] && scan_metamodule; then
            MR_SUPPORT=true
            ME_SUPPORT=true
        elif [ "$APATCH_VER_CODE" -ge "$MIN_VER_APATCH_TRY_METAMODULE" ] && scan_metamodule; then
            MR_SUPPORT=true
            ME_SUPPORT=true
        else
            MR_SUPPORT=false
            ME_SUPPORT=false
            [ "$hide_mode" = "MR" ] || [ "$hide_mode" = "ME" ] && hide_mode="MB"
        fi
    elif [ "$DETECT_MAGISK" = true ]; then
        if [ $MAGISK_V_VER_CODE -ge "$MIN_VER_MAGISK_SUPPORT_MAKENODE" ]; then
            MN_SUPPORT=true
        else
            MN_SUPPORT=false
            [ "$hide_mode" = "MN" ] && hide_mode="MR"
        fi
        MR_SUPPORT=true
    fi

    if [ "$ROOT_SOL_COUNT" -gt 1 ]; then
        hide_mode="MB"
    fi

    [ "$hide_mode" = "MB" ] && mkdir -p "$MIRROR_DIR"

    if [ ! -f "$TARGET_LIST" ]; then
        DESCRIPTION="[❌Target list does not exist!] ${MOD_DESC}"
        update_key_value "description" "$MODULE_PROP" "$DESCRIPTION"
        exit 1
    fi
}

mirror_make_node() {

    local node_path=$1

    if [ -z "$node_path" ]; then
        return 5
    elif [ ! -e "$node_path" ]; then
        return 6
    fi

    local node_path_parent_dir=$(dirname "$node_path")
    local mirror_parent_dir="$MODDIR$node_path_parent_dir"
    local mirror_node_path="$MODDIR$node_path"

    if [ ! -d "$mirror_parent_dir" ]; then
        mkdir -p "$mirror_parent_dir"
    fi

    if [ ! -e "$mirror_node_path" ]; then
        mknod "$mirror_node_path" c 0 0
    else
        return 1
    fi

}

mirror_magisk_replace() {

    local replace_path=$1

    if [ -z "$replace_path" ]; then
        return 5
    elif [ ! -d "$replace_path" ]; then
        return 6
    fi

    local mirror_app_path="$MODDIR$replace_path"

    if [ ! -d "$mirror_app_path" ]; then
        mkdir -p "$mirror_app_path"
    fi

    if [ ! -e "$mirror_app_path/.replace" ]; then
        touch "$mirror_app_path/.replace"
    else
        return 1
    fi

}

link_mount_bind() {

    local link_path=$1
    local target_path=$2

    if [ -z "$link_path" ] || [ -z "$target_path" ]; then
        return 5
    elif [ ! -d "$link_path" ] || [ ! -d "$target_path" ]; then
        return 6
    fi

    mount -o bind "$link_path" "$target_path"

}

create_empty_file() {

    local mirror_empty_path=$1
    local mirror_empty_filename=$2

    if [ -z "$mirror_empty_path" ] || [ -z "$mirror_empty_filename" ]; then
        return 5
    elif [ ! -d "$mirror_empty_path" ]; then
        return 6
    fi

    mkdir -p "$mirror_empty_path"
    touch "${mirror_empty_path}/${mirror_empty_filename}"

}

mirror_mount_empty_file() {
    local empty_path=$1

    if [ -z "$empty_path" ]; then
        return 5
    fi

    if [ -e "$empty_path" ]; then
        if [ -d "$empty_path" ]; then
            for file in "${empty_path}"/*; do
                [ -f "$file" ] || continue
                case $file in
                    *.apk|*.apex|*.capex)  mirror_empty_filename=$(basename "$file")
                    mirror_empty_path="${MODDIR}${empty_path}"
                    create_empty_file "$mirror_empty_path" "$mirror_empty_filename"
                    ;;
                esac
            done
        elif [ -f "$empty_path" ]; then
            mirror_empty_filename=$(basename "$empty_path")
            mirror_empty_dirname=$(dirname "$empty_path")
            mirror_empty_path="${MODDIR}${mirror_empty_dirname}"
            create_empty_file "$mirror_empty_path" "$mirror_empty_filename"
        fi
    else
        return 6
    fi
}

bloat_veil() {

    total_apps_count=0
    vanished_apps_count=0
    duplicated_apps_count=0

    mb_count=0
    mr_count=0
    mn_count=0
    me_count=0

    [ -f "$TARGET_LIST_BVA" ] && rm -f "$TARGET_LIST_BVA"
	touch "$TARGET_LIST_BVA"

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        first_char=$(printf '%s' "$line" | cut -c1)
        [ "$first_char" = "#" ] && continue

        package=$(echo "$line" | cut -d '#' -f1)
        package=$(echo "$package" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$package" ] && continue
        
        case "$package" in
            *\\*)
                package=$(echo "$package" | sed -e 's/\\/\//g')
                ;;
        esac

        total_apps_count=$((total_apps_count+1))

        for path in $system_app_paths; do

            first_char=$(printf '%s' "$line" | cut -c1)
            if [ "$first_char" = "/" ]; then
                app_path="$package"
                case "$app_path" in
                    /apex*|/system/apex*)
                        case "$app_path" in
                            *.apex|*.capex) ;;
                            *)  if [ "${app_path#/apex}" != "$app_path" ]; then
                                    app_path="/system$app_path"
                                fi
                                app_path=$(echo "$app_path" | sed -n 's|^/system/apex/\([^/]*\).*|/system/apex/\1|p')
                                if [ -f "$app_path.apex" ]; then
                                    app_path="$app_path.apex"
                                elif [ -f "$app_path.capex" ]; then
                                    app_path="$app_path.capex"
                                else
                                    break
                                fi
                                ;;
                        esac
                        ;;
                    /app*|/product*|/priv-app*|/system_ext*|/vendor*|/data-app*)
                        app_path="/system$app_path";;
                    /system*)   [ "$app_path" = "/system" ] && break;;
                    *)  break;;
                esac
            else
                app_path="$path/$package"
            fi

            app_name="$(basename "$app_path")"
            if [ -d "$app_path" ]; then
                case "$hide_mode" in
                    "MB")   link_mount_bind "$MIRROR_DIR" "$app_path";;
                    "MR")   mirror_magisk_replace "$app_path";;
                    "ME")   mirror_mount_empty_file "$app_path";;
                    "MN")   mirror_make_node "$app_path";;
                esac
                app_process_result=$?
                if [ $app_process_result -eq 0 ]; then
                    case "$hide_mode" in
                    "MB")   mb_count=$((mb_count + 1));;
                    "MR")   mr_count=$((mr_count + 1));;
                    "ME")   me_count=$((me_count + 1));;
                    "MN")   mn_count=$((mn_count + 1));;
                    esac
                    if check_duplicate_items "$app_path" "$TARGET_LIST_BVA"; then
                        echo "$app_path" >> "$TARGET_LIST_BVA"
                        vanished_apps_count=$((vanished_apps_count + 1))
                    else
                        duplicated_apps_count=$((duplicated_apps_count + 1))
                    fi
                    break
                fi

            elif [ -f "$app_path" ] && [ -d "$(dirname "$app_path")" ]; then
                if [ "$hide_mode" = "ME" ] || [ "$ME_SUPPORT" = true ]; then
                    mirror_mount_empty_file "$app_path"
                    file_process_result=$?
                    if [ $file_process_result -eq 0 ]; then
                        me_count=$((me_count + 1))
                        if check_duplicate_items "$app_path" "$TARGET_LIST_BVA"; then
                            echo "$app_path" >> "$TARGET_LIST_BVA"
                            vanished_apps_count=$((vanished_apps_count + 1))
                        else
                            duplicated_apps_count=$((duplicated_apps_count + 1))
                        fi
                        break
                    fi
                elif [ "$hide_mode" = "MN" ] || [ "$MN_SUPPORT" = true ]; then
                    mirror_make_node "$app_path"
                    file_process_result=$?
                    if [ $file_process_result -eq 0 ]; then
                        mn_count=$((mn_count + 1))
                        if check_duplicate_items "$app_path" "$TARGET_LIST_BVA"; then
                            echo "$app_path" >> "$TARGET_LIST_BVA"
                            vanished_apps_count=$((vanished_apps_count + 1))
                        else
                            duplicated_apps_count=$((duplicated_apps_count + 1))
                        fi
                        break
                    fi
                fi
            else
                if [ "$first_char" = "/" ]; then
                    break
                fi
            fi
        done
    done < "$TARGET_LIST"

    clean_duplicate_items "$TARGET_LIST_BVA"
    cat "$TEMPLATE_FILE" "$TARGET_LIST_BVA" > "${TEMPLATE_FILE}.tmp" && mv "${TEMPLATE_FILE}.tmp" "$TARGET_LIST_BVA"

}

module_status_update() {
    mb_call=false
    
    apps_not_found_count=$((total_apps_count - vanished_apps_count - duplicated_apps_count))

    hide_mode_desc=""
    if [ $mb_count -gt 0 ] && [ $me_count -gt 0 ]; then
        hide_mode_desc="Mount Bind(${mb_count}), Mount Empty(${me_count})"
        mb_call=true
    elif [ $mb_count -gt 0 ] && [ $mn_count -gt 0 ]; then
        hide_mode_desc="Mount Bind(${mb_count}), Make Node(${mn_count})"
        mb_call=true
    elif [ $mr_count -gt 0 ] && [ $me_count -gt 0 ]; then
        hide_mode_desc="Magisk Replace(${mr_count}), Mount Empty File(${me_count})"   
    elif [ $mr_count -gt 0 ] && [ $mn_count -gt 0 ]; then
        hide_mode_desc="Magisk Replace(${mr_count}), Make Node(${mn_count})" 
    elif [ $mb_count -gt 0 ]; then
        hide_mode_desc="Mount Bind"
        mb_call=true
    elif [ $mr_count -gt 0 ]; then
        hide_mode_desc="Magisk Replace"
    elif [ $me_count -gt 0 ]; then
        hide_mode_desc="Mount Empty File"
    elif [ $mn_count -gt 0 ]; then
        hide_mode_desc="Make Node"
    else
        hide_mode_desc="N/A"
    fi

    no_effect=false
    process_status=""

    if [ $vanished_apps_count -gt 0 ]; then
        if [ $apps_not_found_count -gt 0 ]; then
            process_status="✅${vanished_apps_count}/${total_apps_count} App(s)"
        else
            process_status="✅${vanished_apps_count} App(s)"
        fi
    elif [ $duplicated_apps_count -gt 0 ]; then
        if [ $apps_not_found_count -gt 0 ]; then
            process_status="✅${duplicated_apps_count}/${total_apps_count} App(s)"
        else
            process_status="✅${duplicated_apps_count} App(s)"
        fi
    elif [ $total_apps_count -gt 0 ]; then
        process_status="❎0/${total_apps_count} App(s)"
        no_effect=true
    else
        process_status="❌0/0 App(s)"
        no_effect=true
    fi

    if [ "$no_effect" = "false" ]; then
        DESCRIPTION="[${process_status} vanished. ✅${hide_mode_desc}, ✅${ROOT_SOL_DETAIL}] ${MOD_DESC}"
    else
        DESCRIPTION="[${process_status} vanished. ✅${ROOT_SOL_DETAIL}] ${MOD_DESC}"
    fi

    if [ -f "$MODULE_PROP" ]; then
        update_key_value "description" "$MODULE_PROP" "$DESCRIPTION"
        update_key_value "mb_call" "$CONFIG_FILE" "$mb_call"
    fi
}

init_dir "$LAST_WORKED_DIR"
install_env_check
config_loader
unbrick
preparation && bloat_veil
module_status_update
