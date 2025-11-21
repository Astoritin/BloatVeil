#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/wanderer.sh"

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TEMPLATE_DIR="$CONFIG_DIR/template"

TARGET_LIST="$CONFIG_DIR/targets.txt"
TEMPLATE_FILE="$TEMPLATE_DIR/targets_tm.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/BloatVeil_2_$(date +"%Y%m%dT%H%M%S").log"
TARGET_LIST_BVA="$LOG_DIR/targets_bva.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

MOD_INTRO="A bloatware vanishing act on the system"

MN_SUPPORT=false
MR_SUPPORT=false
MIRROR_DIR="$MODDIR/system"

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

    eco "Loading config"
    brick_rescue=$(get_config_var "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    disable_module_as_brick=$(get_config_var "disable_module_as_brick" "$CONFIG_FILE") || disable_module_as_brick=true
    last_worked_target_list=$(get_config_var "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true
    hide_mode=$(get_config_var "hide_mode" "$CONFIG_FILE") || hide_mode=MB
    system_app_paths=$(get_config_var "system_app_paths" "$CONFIG_FILE") || system_app_paths="/system/app /system/product/app /system/product/data-app /system/product/priv-app /system/priv-app /system/system_ext/app /system/system_ext/priv-app /system/vendor/app /system/vendor/priv-app"
    print_line
    print_var "brick_rescue" "disable_module_as_brick" "last_worked_target_list" "hide_mode" "system_app_paths"
    print_line
}

preparation() {

    eco "Some preparation"

    if [ "$MIRROR_DIR" != "/" ] && [ "$MIRROR_DIR" != "/system" ]; then
        rm -rf "$MIRROR_DIR" && eco "Remove old mirror dir"
    fi

    if [ "$DETECT_KSU" = true ] || [ "$DETECT_APATCH" = true ]; then
        eco "Make Node: supported"
        MN_SUPPORT=true
        MR_SUPPORT=false
        [ "$hide_mode" = "MR" ] && hide_mode="MB"
    elif [ "$DETECT_MAGISK" = true ]; then
        if [ $MAGISK_V_VER_CODE -ge 28102 ]; then
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

    mkdir -p "$MIRROR_DIR" && eco "Create new mirror dir"

    if [ ! -f "$TARGET_LIST" ]; then
        eco "Target list does not exist"
        DESCRIPTION="Target list file does not exist❌ | ${ROOT_SOL_DETAIL}🔮 | $MOD_INTRO"
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

bloat_veil() {

    print_line
    eco "Start tricking"
    print_line

    total_apps_count=0
    vanished_apps_count=0
    duplicated_apps_count=0

    mb_count=0
    mr_count=0
    mn_count=0

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
				eco "Custom path specified: $app_path"
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
				eco "Standard path specified: $path/$package"
                app_path="$path/$package"
            fi

            app_name="$(basename "$app_path")"
            if [ -d "$app_path" ]; then
                case "$hide_mode" in
                    "MB")   link_mount_bind "$MIRROR_DIR" "$app_path";;
                    "MR")   mirror_magisk_replace "$app_path";;
                    "MN")   mirror_make_node "$app_path";;
                esac
                app_process_result=$?
                eco "Process APP $app_name ($app_process_result)"
                if [ $app_process_result -eq 0 ]; then
                    case "$hide_mode" in
                    "MB")   mb_count=$((mb_count + 1));;
                    "MR")   mr_count=$((mr_count + 1));;
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

            elif [ -f "$app_path" ] && [ -d "$(dirname $app_path)" ]; then
                if [ "$hide_mode" = "MN" ] || [ "$MN_SUPPORT" = true ]; then
                    mirror_make_node "$app_path"
                    file_process_result=$?
                    eco "Process APP $app_name ($file_process_result)"
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
	cat "$TEMPLATE_FILE" > "${TEMPLATE_FILE}.tmp" && \
	cat "$TARGET_LIST_BVA" >> "${TEMPLATE_FILE}.tmp" && \
	mv "${TEMPLATE_FILE}.tmp" "$TARGET_LIST_BVA"
}

module_status_update() {

    mb_call=false

    apps_not_found_count=$((total_apps_count - vanished_apps_count - duplicated_apps_count))
    print_line
    eco "Vanished: $vanished_apps_count"
    eco "Mount Bind: $mb_count"
    eco "Magisk Replace: $mr_count"
    eco "Make Node: $mn_count"
    print_line
    eco "Duplicate: $duplicated_apps_count"
    eco "Not found: $apps_not_found_count"
    print_line
    eco "In total: $total_apps_count"
    print_line

    [ $mb_count -gt 0 ] && hide_mode_desc="Mount Bind" && mb_call=true
    [ $mr_count -gt 0 ] && hide_mode_desc="Magisk Replace"
    [ $mn_count -gt 0 ] && hide_mode_desc="Make Node"

    if [ $mb_count -gt 0 ] && [ $mn_count -gt 0 ]; then
        hide_mode_desc="Mount Bind(${mb_count}), Make Node(${mn_count})"
    elif [ $mr_count -ne 0 ] && [ $mn_count -ne 0 ]; then
        hide_mode_desc="Magisk Replace(${mr_count}), Make Node(${mn_count})"
    fi

    desc_last_worked=""
    no_effect=false
    [ "$rescue_from_last_worked_target_list" = true ] && desc_last_worked=" (last worked)"

    if [ -f "$MODULE_PROP" ]; then
        if [ $vanished_apps_count -gt 0 ]; then
            if [ $apps_not_found_count -eq 0 ]; then
                DESCRIPTION="Vanished: ${vanished_apps_count}✨"
            else
                DESCRIPTION="Vanished: ${vanished_apps_count}✨ | Not found: ${apps_not_found_count}❎ | In total: ${total_apps_count}📋"
            fi
        else
            if [ $total_apps_count -gt 0 ]; then
                if [ $duplicated_apps_count -gt 0 ]; then
                    DESCRIPTION="Vanished: ${duplicated_apps_count}✨"
                else
                    DESCRIPTION="Standby⏳ | Not found: ${total_apps_count}❎"
                    no_effect=true
                fi
            else
                DESCRIPTION="No valid items found in target list❌"
                no_effect=true
            fi
        fi
        [ "$no_effect" = false ] && DESCRIPTION="${DESCRIPTION} | ${hide_mode_desc}${desc_last_worked} mode🤖 | ${ROOT_SOL_DETAIL}🔮 | $MOD_INTRO"
        [ "$no_effect" = true ] && DESCRIPTION="${DESCRIPTION} | ${ROOT_SOL_DETAIL}🔮 | $MOD_INTRO"
        update_config_var "description" "$MODULE_PROP" "$DESCRIPTION"
        update_config_var "mb_call" "$CONFIG_FILE" "$mb_call"
    fi

}

module_cleanup_schedule() {

    POST_D="/data/adb/post-fs-data.d/"
    CLEANUP_SH="bloat_veil_cleanup.sh"
    CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

    if [ ! -f "$CLEANUP_PATH" ]; then
        mkdir -p "$POST_D"
        cat "$MODDIR/${CLEANUP_SH}" > "$CLEANUP_PATH"
        chmod +x "$CLEANUP_PATH"
    fi

}

init_dir "$TEMPLATE_DIR" "$LOG_DIR"
module_intro
show_system_info
print_line
config_loader
unbrick
preparation && bloat_veil
module_status_update
module_cleanup_schedule
eco "All done!"
