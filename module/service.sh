#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/wanderer.sh"

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/targets.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/bloat_veil_$(date +"%Y%m%dT%H%M%S").txt"
LOG_FILE_2="$LOG_DIR/logs_2.txt"
TARGET_LIST_BVA="$LOG_DIR/targets_bva.txt"

MODULE_PROP="$MODDIR/module.prop"
MOD_NAME="$(get_key_value "name" "$MODULE_PROP")"
MOD_DESC="A bloatware vanishing act on the system."

config_loader() {

    eco "Loading config for late_start service stage"
    brick_rescue=$(get_key_value "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    brick_timeout=$(get_key_value "brick_timeout" "$CONFIG_FILE") || brick_timeout=120
    brick_and_disable=$(get_key_value "brick_and_disable" "$CONFIG_FILE") || brick_and_disable=true
    last_worked_target_list=$(get_key_value "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true
    hide_mode=$(get_key_value "hide_mode" "$CONFIG_FILE") || hide_mode=MB
    mb_umount_bind=$(get_key_value "mb_umount_bind" "$CONFIG_FILE") || mb_umount_bind=true
    auto_update_target_list=$(get_key_value "auto_update_target_list" "$CONFIG_FILE") || auto_update_target_list=true
    mb_call=$(get_key_value "mb_call" "$CONFIG_FILE") || mb_call=false
    ecoe
    print_var "brick_rescue" "brick_timeout" "brick_and_disable" "last_worked_target_list" "hide_mode" "mb_umount_bind" "auto_update_target_list" "mb_call"
    ecoe

}

module_cleanup_schedule() {

    POST_D="/data/adb/post-fs-data.d/"
    CLEANUP_SH="cleanup_bloat_veil.sh"
    CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

    if [ ! -f "$CLEANUP_PATH" ]; then
        mkdir -p "$POST_D"
        cat "$MODDIR/${CLEANUP_SH}" > "$CLEANUP_PATH"
        chmod +x "$CLEANUP_PATH"
    fi

}

module_cleanup_schedule
clean_dir_if_reach_max "$LOG_DIR"
install_env_check
ecoe
config_loader

if [ "$brick_rescue" = true ] && [ -f "$FLAG_BRICKED" ]; then
    eco "Flag bricked: exists
    $MOD_NAME: skipped"
    exit 1
fi

eco "Timeout: ${brick_timeout}s"
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    if [ $brick_timeout -le "0" ]; then
        ecoe
        eco "Flag bricked: set"
        touch "$FLAG_BRICKED"
        if [ "$brick_rescue" = false ]; then
            eco "Unbrick: skipped"
            exit 1
        fi
        if [ "$brick_and_disable" = true ]; then
            eco "$MOD_NAME: disabled"
            touch "$MODDIR/disable"
        fi
        DESCRIPTION="[❌Triggered brick rescue! ✅${ROOT_SOL_DETAIL}] $MOD_DESC"
        update_key_value "description" "$MODULE_PROP" "$DESCRIPTION"
		sync
        setprop sys.powerctl reboot
        result_set_prop=$?
        eco "setprop sys.powerctl reboot ($result_set_prop)"
        sleep 5
        eco "Reboot: failed"
        exit 1
    fi
    brick_timeout=$((brick_timeout-1))
    sleep 1
done

eco "Boot complete!
Countdown: ${brick_timeout}s"

rm -f "$FLAG_BRICKED"

if [ "$mb_call" = true ] && [ "$mb_umount_bind" = true ]; then
    ecoe
    if [ ! -f "$TARGET_LIST_BVA" ]; then
        eco "$TARGET_LIST_BVA: -"
    else
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
                    eco "$package: skipped"
                    continue
                    ;;
            esac

            umount -f $package
            result_umount=$?
            eco "unmount -f $package ($result_umount)"
            if [ $result_umount -eq 0 ]; then
                UMOUNT_APPS_COUNT=$((UMOUNT_APPS_COUNT + 1))
            fi
        done < "$TARGET_LIST_BVA"
        ecoe
        eco "Unmounted: $UMOUNT_APPS_COUNT App(s)"
        eco "In total: $TOTAL_APPS_COUNT App(s)"
        ecoe
    fi
else
    [ "$mb_call" = false ] && eco "Mount Bind: -"
    [ "$mb_umount_bind" = false ] && eco "Umount: disabled"
fi

if [ "$last_worked_target_list" = true ]; then
    if [ "$auto_update_target_list" = true ]; then
        cp "$TARGET_LIST_BVA" "$TARGET_LIST_LW"
    elif [ "$auto_update_target_list" = false ]; then
        cp "$TARGET_LIST" "$TARGET_LIST_LW"
    fi
fi
if [ "$auto_update_target_list" = true ]; then
    cp -p "$TARGET_LIST_BVA" "$TARGET_LIST"
fi
rm -f "$TARGET_LIST_BVA"

cat "$LOG_FILE_2" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
rm -f "$LOG_FILE_2"
remove_config_var "mb_call" "$CONFIG_FILE"
