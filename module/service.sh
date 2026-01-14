#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/wanderer.sh"

MOD_DESC="A bloatware vanishing act on the system."

CONFIG_DIR="/data/adb/bloat_veil"

CONFIG_FILE="$CONFIG_DIR/settings.conf"
TARGET_LIST="$CONFIG_DIR/targets.txt"
TARGET_LIST_BVA="$CONFIG_DIR/targets_bva.txt"

LAST_WORKED_DIR="$CONFIG_DIR/last_worked"
TARGET_LIST_LW="$LAST_WORKED_DIR/targets_lw.txt"

FLAG_BRICKED="$CONFIG_DIR/bricked"

MODULE_PROP="$MODDIR/module.prop"
MOD_NAME="$(get_key_value "name" "$MODULE_PROP")"

config_loader() {

    brick_rescue=$(get_key_value "brick_rescue" "$CONFIG_FILE") || brick_rescue=true
    brick_timeout=$(get_key_value "brick_timeout" "$CONFIG_FILE") || brick_timeout=120
    brick_and_disable=$(get_key_value "brick_and_disable" "$CONFIG_FILE") || brick_and_disable=true
    last_worked_target_list=$(get_key_value "last_worked_target_list" "$CONFIG_FILE") || last_worked_target_list=true
    mb_umount_bind=$(get_key_value "mb_umount_bind" "$CONFIG_FILE") || mb_umount_bind=true
    auto_update_target_list=$(get_key_value "auto_update_target_list" "$CONFIG_FILE") || auto_update_target_list=true
    mb_call=$(get_key_value "mb_call" "$CONFIG_FILE") || mb_call=false

}

module_description_cleanup_schedule() {

    POST_D="/data/adb/post-fs-data.d/"
    CLEANUP_SH="bloat_veil_unbrick.sh"
    CLEANUP_PATH="${POST_D}/${CLEANUP_SH}"

    if [ ! -f "$CLEANUP_PATH" ]; then
        mkdir -p "$POST_D"
        cat "$MODDIR/${CLEANUP_SH}" > "$CLEANUP_PATH"
        chmod +x "$CLEANUP_PATH"
    fi

}

module_description_cleanup_schedule
config_loader

if [ "$brick_rescue" = true ] && [ -f "$FLAG_BRICKED" ]; then
    exit 1
fi

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    if [ $brick_timeout -le "0" ]; then
        touch "$FLAG_BRICKED"
        if [ "$brick_rescue" = false ]; then
            exit 1
        fi
        if [ "$brick_and_disable" = true ]; then
            touch "$MODDIR/disable"
        fi
        DESCRIPTION="[❌Triggered brick rescue!] $MOD_DESC"
        update_key_value "description" "$MODULE_PROP" "$DESCRIPTION"
		sync
        setprop sys.powerctl reboot
        sleep 5
        exit 1
    fi
    brick_timeout=$((brick_timeout-1))
    sleep 1
done

rm -f "$FLAG_BRICKED"

if [ "$mb_call" = true ] && [ "$mb_umount_bind" = true ]; then
    if [ -f "$TARGET_LIST_BVA" ]; then
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
            case "$package" in
                *.apex|*.capex) continue;;
            esac

            umount -f $package
        done < "$TARGET_LIST_BVA"
    fi
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
remove_key_value "mb_call" "$CONFIG_FILE"
