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
LOG_FILE="$LOG_DIR/BloatVeil_4_$(date +"%Y%m%dT%H%M%S").txt"
TARGET_LIST_BVA="$LOG_DIR/targets_bva.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

MOD_INTRO="A bloatware vanishing act on the system"

config_loader() {

    eco "Loading config"

    brick_rescue=$(get_config_var "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    brick_timeout=$(get_config_var "brick_timeout" "$CONFIG_FILE") || brick_timeout=120
    disable_module_as_brick=$(get_config_var "disable_module_as_brick" "$CONFIG_FILE") || disable_module_as_brick=true
    last_worked_target_list=$(get_config_var "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true
    hide_mode=$(get_config_var "hide_mode" "$CONFIG_FILE") || hide_mode=MB
    mb_umount_bind=$(get_config_var "mb_umount_bind" "$CONFIG_FILE") || mb_umount_bind=true
    auto_update_target_list=$(get_config_var "auto_update_target_list" "$CONFIG_FILE") || auto_update_target_list=true
    mb_call=$(get_config_var "mb_call" "$CONFIG_FILE") || mb_call=false
    ecol
    print_var "brick_rescue" "brick_timeout" "disable_module_as_brick" "last_worked_target_list" "hide_mode" "mb_umount_bind" "auto_update_target_list" "mb_call"
    ecol

}

clean_dir_if_reach_max "$LOG_DIR"
module_intro
show_system_info
ecol
config_loader

if [ "$brick_rescue" = true ] && [ -f "$FLAG_BRICKED" ]; then
    eco "Flag bricked exists!"
	eco "Skip processing"
    exit 1
fi

eco "Set timeout: ${brick_timeout}s"
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    if [ $brick_timeout -le "0" ]; then
        ecol
		eco "Booting timeout reached!"
        eco "Set flag bricked"
        touch "$FLAG_BRICKED"
        if [ "$brick_rescue" = false ]; then
            eco "Skip birck rescue"
            exit 1
        fi
        if [ "$disable_module_as_brick" = true ]; then
            eco "Disable $MOD_NAME"
            touch "$MODDIR/disable"
        fi
        DESCRIPTION="Trigger brick rescue ❌ | ${ROOT_SOL_DETAIL} 🔮 | $MOD_INTRO"
        update_config_var "description" "$MODULE_PROP" "$DESCRIPTION"
        eco "Request system for sync"
		sync
		eco "setprop sys.powerctl reboot"
        setprop sys.powerctl reboot
        sleep 5
        eco "Failed to reboot system, exiting"
        exit 1
    fi
    brick_timeout=$((brick_timeout-1))
    sleep 1
done

eco "Boot complete! Countdown: ${brick_timeout}s"
rm -f "$FLAG_BRICKED"

if [ "$mb_call" = true ] && [ "$mb_umount_bind" = true ]; then
    ecol
    if [ ! -f "$TARGET_LIST_BVA" ]; then
        eco "$TARGET_LIST_BVA does not exist"
		eco "$MOD_NAME will not unmount bind points"
    else
        eco "Processing bind points"
        TOTAL_APPS_COUNT=0
        UMOUNT_APPS_COUNT=0
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -z "$line" ] && continue

            first_char=$(printf '%s' "$line" | cut -c1)
            [ "$first_char" = "#" ] && continue

            package=$(echo "$line" | cut -d '#' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -z "$package" ] && continue
            
            case "$package" in
                *\\*)
                    package=$(echo "$package" | sed -e 's/\\/\//g')
                    ;;
            esac

            TOTAL_APPS_COUNT=$((TOTAL_APPS_COUNT + 1))

            case "$package" in
                *.apex|*.capex)
                    eco "Skip $package"
                    continue
                    ;;
            esac

            umount -f $package
            result_umount=$?
            eco "Unmount $package ($result_umount)"
            app_name="$(basename "$package")"
            if [ $result_umount -eq 0 ]; then
                UMOUNT_APPS_COUNT=$((UMOUNT_APPS_COUNT + 1))
            fi
        done < "$TARGET_LIST_BVA"
        ecol
        eco "Unmounted: $UMOUNT_APPS_COUNT App(s)"
        eco "Total: $TOTAL_APPS_COUNT App(s)"
        ecol
    fi
else
    [ "$mb_call" = false ] && eco "No items uses Mount Bind method"
    [ "$mb_umount_bind" = false ] && eco "Umounting point by Mount Bind method is disabled"
fi

if [ "$last_worked_target_list" = true ]; then
    eco "Backup last worked target list"
    [ ! -d "$LAST_WORKED_DIR" ] && mkdir -p "$LAST_WORKED_DIR"
    if [ "$auto_update_target_list" = true ]; then
        cp "$TARGET_LIST_BVA" "$TARGET_LIST_LW"
    elif [ "$auto_update_target_list" = false ]; then
        cp "$TARGET_LIST" "$TARGET_LIST_LW"
    fi
fi
if [ "$auto_update_target_list" = true ]; then
    eco "Update target list"
    cp -p "$TARGET_LIST_BVA" "$TARGET_LIST"
fi
rm -f "$TARGET_LIST_BVA" && eco "Remove old temporary file"
remove_config_var "mb_call" "$CONFIG_FILE"
ecol
eco "All done!"