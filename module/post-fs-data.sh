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
        eco "Skip brick rescue"
        return 1
    fi

    rescue_from_last_worked_target_list=false

    if [ -f "$FLAG_BRICKED" ]; then
        eco "Flag bricked exists!"
        if file_compare "$TARGET_LIST_LW" "$TARGET_LIST"; then
            eco "Last worked target list is identical to current target list"
            rm -f "$TARGET_LIST_LW" && eco "Remove last worked target list"
        fi
        if [ "$disable_module_as_brick" = false ] && [ "$last_worked_target_list" = true ]; then
			eco "Attempt to rescue from last worked target list"
            if [ -f "$TARGET_LIST_LW" ]; then
				eco "Last worked target list exists"
                cp "$TARGET_LIST_LW" "$TARGET_LIST" && eco "Switch to last worked target list"
                rm -f "$MODDIR/disable" && eco "Enable $MOD_NAME again"
                rm -f "$FLAG_BRICKED" && eco "Reset brick state"
                rescue_from_last_worked_target_list=true
                return 0
            fi
        fi
        if [ "$disable_module_as_brick" = true ] && [ ! -f "$MODDIR/disable" ]; then
            eco "Flag bricked exists"
            eco "Flag disable does not exist"
            rm -f "$FLAG_BRICKED" && eco "Remove flag bricked"
            return 0
        else
            exit 1
        fi
    else
        eco "Flag bricked does not exist"
    fi
}

config_loader() {

    eco "Loading config for post-fs-data mode"
    brick_rescue=$(get_config_var "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    disable_module_as_brick=$(get_config_var "disable_module_as_brick" "$CONFIG_FILE") || disable_module_as_brick=true
    last_worked_target_list=$(get_config_var "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true
    hide_mode=$(get_config_var "hide_mode" "$CONFIG_FILE") || hide_mode=MB
    system_app_paths=$(get_config_var "system_app_paths" "$CONFIG_FILE") || system_app_paths="/system/app /system/preload /system/product/app /system/product/data-app /system/product/priv-app /system/product/overlay /system/priv-app /system/system_ext/app /system/system_ext/priv-app /system/vendor/app /system/vendor/priv-app /system/vendor/overlay"
    ecol
    print_var "brick_rescue" "disable_module_as_brick" "last_worked_target_list" "hide_mode" "system_app_paths"
    ecol
}

preparation() {

    eco "Some preparation"

    [ -d "$MIRROR_DIR" ] && rm -rf "$MIRROR_DIR" && eco "Remove old mirror dir"
    [ -d "$MIRROR_SYSTEM_DIR" ] && rm -rf "$MIRROR_SYSTEM_DIR" && eco "Remove old mirror dir"    

    if [ "$DETECT_KSU" = true ] || [ "$DETECT_APATCH" = true ]; then
        eco "Make Node: supported"
        MN_SUPPORT=true
        if [ "$KSU_KERNEL_VER_CODE" -ge "$MIN_VER_KERNELSU_SUPPORT_MOUNTING" ] && checkout_metamodule; then
            eco "Current metamodule: ${current_module_name} ${current_module_ver_name} (${current_module_ver_code})"
            eco " "
            eco "Magisk Replace: supported (with proper metamodule)"
            eco "Make Node: supported (with proper metamodule)"
            eco "Make Empty File: supported (with proper metamodule)"
            eco " "
            eco "Users need to judge manually whether their metamodule supports"
            eco "these modes or not, $MOD_NAME will always take it as true"
            eco "if KernelSU version newer than $MIN_VER_KERNELSU_SUPPORT_MOUNTING"
            MR_SUPPORT=true
        else
            eco "No metamodule found or KernelSU version"
            eco "doesn't require metamodule for mounting!"
            eco "Revert to Mount Bind mode"
            MR_SUPPORT=false
            [ "$hide_mode" = "MR" ] && hide_mode="MB"
        fi
    elif [ "$DETECT_MAGISK" = true ]; then
        if [ $MAGISK_V_VER_CODE -ge "$MIN_VER_MAGISK_SUPPORT_MAKENODE" ]; then
            eco "Make Node: supported"
            MN_SUPPORT=true
        else
            MN_SUPPORT=false
            if [ "$hide_mode" = "MN" ]; then
                eco "Make Node: unsupported"
                eco "$MOD_NAME will revert to Magisk Replace mode"
                hide_mode="MR"
            fi
        fi
        eco "Magisk Replace: supported"
        MR_SUPPORT=true
    fi

    if [ "$ROOT_SOL_COUNT" -gt 1 ]; then
        eco "Find multiple root solutions"
        eco "$MOD_NAME will revert to Mount Bind mode to ensure maximum compatibility"
        hide_mode="MB"
    fi

    [ "$hide_mode" = "MB" ] && mkdir -p "$MIRROR_DIR" && eco "Create new mirror dir"

    if [ ! -f "$TARGET_LIST" ]; then
        eco "Target list does not exist"
        DESCRIPTION="[❌Target list does not exist! ✅${ROOT_SOL_DETAIL}] ${MOD_INTRO}"
        update_config_var "description" "$MODULE_PROP" "$DESCRIPTION"
        exit 1
    fi
}

mirror_make_node() {

    node_path=$1

    if [ -z "$node_path" ]; then
        return 5
    elif [ ! -e "$node_path" ]; then
        return 6
    fi

    node_path_parent_dir=$(dirname "$node_path")
    mirror_parent_dir="$MODDIR$node_path_parent_dir"
    mirror_node_path="$MODDIR$node_path"

    if [ ! -d "$mirror_parent_dir" ]; then
        mkdir -p "$mirror_parent_dir" && eco "Created parent dir $mirror_parent_dir"
    fi

    if [ ! -e "$mirror_node_path" ]; then
        mknod "$mirror_node_path" c 0 0
        result_make_node="$?"
        return $result_make_node
    else
        return 1
    fi

}

mirror_magisk_replace() {

    replace_path=$1

    if [ -z "$replace_path" ]; then
        return 5
    elif [ ! -d "$replace_path" ]; then
        return 6
    fi

    mirror_app_path="$MODDIR$replace_path"

    if [ ! -d "$mirror_app_path" ]; then
        mkdir -p "$mirror_app_path" && eco "Created mirror path $mirror_app_path"
    fi

    if [ ! -e "$mirror_app_path/.replace" ]; then
        touch "$mirror_app_path/.replace"
        result_magisk_replace="$?"
        return $result_magisk_replace
    else
        return 1
    fi

}

link_mount_bind() {

    link_path=$1
    target_path=$2

    if [ -z "$link_path" ] || [ -z "$target_path" ]; then
        return 5
    elif [ ! -d "$link_path" ] || [ ! -d "$target_path" ]; then
        return 6
    fi

    mount -o bind "$link_path" "$target_path"
    result_mount_bind="$?"
    return $result_mount_bind
}

mirror_mount_empty_file() {

    empty_path=$1

    [ -z "$empty_path" ] && return 5

    if [ -d "$empty_path" ]; then
        for file in "${empty_path}"/*; do
            [ -f "$file" ] || continue
            case $file in
                *.apk|*.apex|*.capex)  mirror_empty_filename=$(basename "$file")
                        mirror_empty_path="${MODDIR}${empty_path}"
                        mkdir -p "$mirror_empty_path"
                        result_mkdir=$?
                        touch "${mirror_empty_path}/${mirror_empty_filename}"
                        result_touch=$?
                        [ $result_mkdir -eq 0 ] && [ $result_touch -eq 0 ] && return 0
                        [ $result_mkdir -eq 0 ] && return 1
                        [ $result_touch -eq 0 ] && return 2
                    ;;
                *)  ;;
            esac
        done
    elif [ -f "$empty_path" ]; then
        mirror_empty_filename=$(basename "$empty_path")
        mirror_empty_dirname=$(dirname "$empty_path")
        mirror_empty_path="${MODDIR}${mirror_empty_dirname}"
        mkdir -p "$mirror_empty_path"
        result_mkdir=$?
        touch "${mirror_empty_path}/${mirror_empty_filename}"
        result_touch=$?
        [ $result_mkdir -eq 0 ] && [ $result_touch -eq 0 ] && return 0
        [ $result_mkdir -eq 0 ] && return 1
        [ $result_touch -eq 0 ] && return 2
    else
        return 6
    fi

}

bloat_veil() {

    ecol
    eco "Start tricking"
    ecol

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

    clean_duplicate_items "$TARGET_LIST_BVA" && eco "Clean duplicate items"
    cat "$TEMPLATE_FILE" "$TARGET_LIST_BVA" > "${TEMPLATE_FILE}.tmp" && mv "${TEMPLATE_FILE}.tmp" "$TARGET_LIST_BVA"

}

module_status_update() {
    mb_call=false
    
    apps_not_found_count=$((total_apps_count - vanished_apps_count - duplicated_apps_count))
    
    ecol
    eco "Vanished: ${vanished_apps_count} App(s)"
    eco "Mount Bind: ${mb_count} App(s) | Magisk Replace: ${mr_count} App(s)" 
    eco "Make Node: ${mn_count} App(s) | Mount Empty File: ${me_count} App(s)"
    ecol
    eco "Duplicate: ${duplicated_apps_count} App(s) | Not found: ${apps_not_found_count} App(s)"
    eco "In total: ${total_apps_count} App(s)"

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
ecol
config_loader
unbrick
preparation && bloat_veil
module_status_update
