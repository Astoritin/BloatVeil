#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/wanderer.sh"

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/targets.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"
TEMPLATE_FILE="$LAST_WORKED_DIR/targets_tm.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/logs_2.txt"
TARGET_LIST_BVA="$LOG_DIR/targets_bva.txt"

MOD_INTRO="A bloatware vanishing act on the system."

MN_SUPPORT=false
MR_SUPPORT=false
MIN_VER_MAGISK_SUPPORT_MAKENODE=28102
MIN_VER_KERNELSU_SUPPORT_MOUNTING=22098

MIRROR_DIR="$MODDIR/mirror"
MIRROR_SYSTEM_DIR="$MODDIR/system"

[ -f "$LOG_FILE" ] && rm -f "$LOG_FILE"

unbrick() {
    if [ "$brick_rescue" = false ]; then
        eco "Unbrick: skipped"
        return 1
    fi

    rescue_from_last_worked_target_list=false

    if [ -f "$FLAG_BRICKED" ]; then
        eco "Flag bricked: exists"
        if file_compare "$TARGET_LIST_LW" "$TARGET_LIST"; then
            eco "Last worked vs current: identical"
            rm -f "$TARGET_LIST_LW" && eco "Last worked: removed"
        fi
        if [ "$disable_module_as_brick" = false ] && [ "$last_worked_target_list" = true ]; then
            if [ -f "$TARGET_LIST_LW" ]; then
				eco "Last worked: exists"
                cp "$TARGET_LIST_LW" "$TARGET_LIST" && eco "Last worked: switched"
                rm -f "$MODDIR/disable" && eco "${MOD_NAME}: enabled"
                rm -f "$FLAG_BRICKED" && eco "Brick state: reset"
                rescue_from_last_worked_target_list=true
                return 0
            fi
        fi
        if [ "$disable_module_as_brick" = true ] && [ ! -f "$MODDIR/disable" ]; then
            eco "Mark disable: -"
            rm -f "$FLAG_BRICKED" && eco "Flag bricked: removed"
            return 0
        else
            exit 1
        fi
    else
        eco "Flag bricked: -"
    fi
}

config_loader() {

    eco "Loading config for post-fs-data stage"
    brick_rescue=$(get_config_var "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    disable_module_as_brick=$(get_config_var "disable_module_as_brick" "$CONFIG_FILE") || disable_module_as_brick=true
    last_worked_target_list=$(get_config_var "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true
    hide_mode=$(get_config_var "hide_mode" "$CONFIG_FILE") || hide_mode=MB
    system_app_paths=$(get_config_var "system_app_paths" "$CONFIG_FILE") || system_app_paths="/system/app /system/preload /system/product/app /system/product/data-app /system/product/priv-app /system/product/overlay /system/priv-app /system/system_ext/app /system/system_ext/priv-app /system/vendor/app /system/vendor/priv-app /system/vendor/overlay"
    ecoe
    print_var "brick_rescue" "disable_module_as_brick" "last_worked_target_list" "hide_mode" "system_app_paths"
    ecoe
}

preparation() {

    eco "Some preparation"

    [ -d "$MIRROR_DIR" ] && rm -rf "$MIRROR_DIR" && eco "Old mirror dir: removed"
    [ -d "$MIRROR_SYSTEM_DIR" ] && rm -rf "$MIRROR_SYSTEM_DIR" && eco "Old system dir: removed"    

    if [ "$DETECT_KSU" = true ] || [ "$DETECT_APATCH" = true ]; then
        eco "Make Node: ok"
        MN_SUPPORT=true
        if [ "$KSU_KERNEL_VER_CODE" -ge "$MIN_VER_KERNELSU_SUPPORT_MOUNTING" ] && checkout_metamodule; then
            eco "Current metamodule: ${current_module_name} ${current_module_ver_name} (${current_module_ver_code})"
            eco " "
            eco "Magisk Replace: ok (with proper metamodule)"
            eco "Make Node: ok (with proper metamodule)"
            eco "Make Empty File: ok (with proper metamodule)"
            eco " "
            MR_SUPPORT=true
            ME_SUPPORT=true
        else
            if [ "$KSU_KERNEL_VER_CODE" -lt "$MIN_VER_KERNELSU_SUPPORT_MOUNTING" ]; then
                eco "KernelSU version: ${KSU_KERNEL_VER_CODE} (<${MIN_VER_KERNELSU_SUPPORT_MOUNTING})"
            elif ! checkout_metamodule; then
                eco "Metamodule: -"
            fi
            eco " "
            eco "Magisk Replace: -"
            eco "Make Node: ok"
            eco "Make Empty File: -"
            eco " "
            eco "Reverted to: Mount Bind"
            MR_SUPPORT=false
            ME_SUPPORT=false
            [ "$hide_mode" = "MR" ] || [ "$hide_mode" = "ME" ] && hide_mode="MB"
        fi
    elif [ "$DETECT_MAGISK" = true ]; then
        if [ $MAGISK_V_VER_CODE -ge "$MIN_VER_MAGISK_SUPPORT_MAKENODE" ]; then
            eco "Make Node: ok"
            MN_SUPPORT=true
        else
            MN_SUPPORT=false
            if [ "$hide_mode" = "MN" ]; then
                eco "Make Node: -"
                eco "Reverted to: Magisk Replace"
                hide_mode="MR"
            fi
        fi
        eco "Magisk Replace: ok"
        MR_SUPPORT=true
    fi

    if [ "$ROOT_SOL_COUNT" -gt 1 ]; then
        eco "Multiple root: exists"
        eco "Reverted to: Mount Bind"
        hide_mode="MB"
    fi

    [ "$hide_mode" = "MB" ] && mkdir -p "$MIRROR_DIR" && eco "Create new mirror dir"

    if [ ! -f "$TARGET_LIST" ]; then
        eco "Target list: -"
        DESCRIPTION="[❌Target list does not exist! ✅${ROOT_SOL_DETAIL}] ${MOD_INTRO}"
        update_config_var "description" "$MODULE_PROP" "$DESCRIPTION"
        exit 1
    fi
}

mirror_make_node() {
    node_path=$1

    if [ -z "$node_path" ]; then
        eco "node_path: null"
        return 5
    elif [ ! -e "$node_path" ]; then
        eco "$node_path: -"
        return 6
    fi

    node_path_parent_dir=$(dirname "$node_path")
    mirror_parent_dir="$MODDIR$node_path_parent_dir"
    mirror_node_path="$MODDIR$node_path"

    if [ ! -d "$mirror_parent_dir" ]; then
        mkdir -p "$mirror_parent_dir" && eco "$mirror_parent_dir: created"
    fi

    if [ ! -e "$mirror_node_path" ]; then
        mknod "$mirror_node_path" c 0 0
        result_make_node="$?"
        eco "mknod $mirror_node_path c 0 0 ($result_make_node)"
        return $result_make_node
    else
        eco "$mirror_node_path: exists already"
        return 1
    fi

}

mirror_magisk_replace() {
    replace_path=$1

    if [ -z "$replace_path" ]; then
        eco "replace_path: null"
        return 5
    elif [ ! -d "$replace_path" ]; then
        eco "$replace_path: -"
        return 6
    fi

    mirror_app_path="$MODDIR$replace_path"

    if [ ! -d "$mirror_app_path" ]; then
        mkdir -p "$mirror_app_path" && eco "$mirror_app_path: created"
    fi

    if [ ! -e "$mirror_app_path/.replace" ]; then
        touch "$mirror_app_path/.replace"
        result_magisk_replace="$?"
        eco "touch $mirror_app_path/.replace ($result_magisk_replace)"
        return $result_magisk_replace
    else
        eco "$mirror_app_path/.replace: exists already"
        return 1
    fi

}

link_mount_bind() {
    link_path=$1
    target_path=$2

    if [ -z "$link_path" ] || [ -z "$target_path" ]; then
        eco "link_path or target_path: null"
        return 5
    elif [ ! -d "$link_path" ] || [ ! -d "$target_path" ]; then
        eco "$link_path or $target_path: -"
        return 6
    fi

    mount -o bind "$link_path" "$target_path"
    result_mount_bind="$?"
    eco "mount -o bind $link_path $target_path ($result_mount_bind)"
    return $result_mount_bind
}

create_empty_file() {
    mirror_empty_path=$1
    mirror_empty_filename=$2

    mkdir -p "$mirror_empty_path"
    result_mkdir=$?
    touch "${mirror_empty_path}/${mirror_empty_filename}"
    result_touch=$?

    eco "mkdir -p $mirror_empty_path ($result_mkdir)"
    eco "touch ${mirror_empty_path}/${mirror_empty_filename} ($result_touch)"

    [ $result_mkdir -eq 0 ] && [ $result_touch -eq 0 ] && return 0
    [ $result_mkdir -eq 0 ] && return 1
    [ $result_touch -eq 0 ] && return 2

}

mirror_mount_empty_file() {
    empty_path=$1

    if [ -z "$empty_path" ]; then
        eco "empty_path: null"
        return 5
    fi

    if [ -e "$empty_path" ]; then
        if [ -d "$empty_path" ]; then
            eco "$empty_path type: dir"
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
            eco "$empty_path type: file"
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

    ecoe
    eco "Start tricking"
    ecoe

    total_apps_count=0
    vanished_apps_count=0
    duplicated_apps_count=0

    mb_count=0
    mr_count=0
    mn_count=0
    me_count=0

    [ -f "$TARGET_LIST_BVA" ] && rm -f "$TARGET_LIST_BVA" && eco "Remove old temporary file"
	touch "$TARGET_LIST_BVA" && eco "Created empty temporary file"

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
				eco "Checking custom path: $app_path"
                case "$app_path" in
                    /apex*|/system/apex*)
                        case "$app_path" in
                            *.apex|*.capex) ;;
                            *)  if [ "${app_path#/apex}" != "$app_path" ]; then
                                    eco "Redirect to /system$app_path"
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
                        eco "Redirect to /system$app_path"
                        app_path="/system$app_path";;
                    /system*)   [ "$app_path" = "/system" ] && break;;
                    *)  break;;
                esac
            else
				eco "Checking standard path: $path/$package"
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
                eco "Processing APP $app_name ($app_process_result)"
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
                if [ "$hide_mode" = "ME" ]; then
                    mirror_mount_empty_file "$app_path"
                    file_process_result=$?
                    eco "Processing APP $app_name ($file_process_result)"
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
                    eco "Processing APP $app_name ($file_process_result)"
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
                    eco "Custom path $app_path does not exist"
                    break
                else
                    eco "Standard path $app_path does not exist"
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
    
    ecoe
    eco "Vanished: ${vanished_apps_count} App(s) (MB: ${mb_count}, MR: ${mr_count}, MN: ${mn_count}, ME: ${me_count})"
    eco "Duplicate: ${duplicated_apps_count} App(s), not found: ${apps_not_found_count} App(s), in total: ${total_apps_count} App(s)"

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

    desc_last_worked=""
    no_effect=false
    process_status=""
    
    if [ "$rescue_from_last_worked_target_list" = "true" ]; then
        desc_last_worked=" (last worked)"
    fi

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
l
    if [ "$no_effect" = "false" ]; then
        DESCRIPTION="[${process_status} vanished, ✅${hide_mode_desc}${desc_last_worked}, ✅${ROOT_SOL_DETAIL}] ${MOD_INTRO}"
    else
        DESCRIPTION="[${process_status} vanished, ✅${ROOT_SOL_DETAIL}] ${MOD_INTRO}"
    fi

    if [ -f "$MODULE_PROP" ]; then
        update_config_var "description" "$MODULE_PROP" "$DESCRIPTION"
        update_config_var "mb_call" "$CONFIG_FILE" "$mb_call"
    fi
}

init_dir "$LAST_WORKED_DIR" "$LOG_DIR"
module_intro
show_system_info
ecoe
config_loader
unbrick
preparation && bloat_veil
module_status_update
