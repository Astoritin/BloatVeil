#!/system/bin/sh

update_key_value() {
    local key="$1"
    local conf="$2"
    local expected="$3"

    [ -z "$key" ] || [ -z "$expected" ] || [ -z "$conf" ] || [ ! -f "$conf" ] && return 1

    if grep -q "^${key}=" "$conf"; then
        sed -i "/^${key}=/c\\${key}=${expected}" "$conf"
    else
        [ -n "$(tail -c1 "$conf")" ] && echo >> "$conf"
        printf '%s=%s\n' "$key" "$expected" >> "$conf"
    fi
}

MODS_DIR="/data/adb/modules /data/adb/lite_modules"
MOD_NAME="bloat_veil"
MOD_DESC="A bloatware vanishing act on the system."

for MOD_DIR in $MODS_DIR; do
    MOD_DIR="$MOD_DIR/$MOD_NAME"
    [ -f "$MOD_DIR/disable" ] && update_key_value "description" "$MOD_DIR/module.prop" "$MOD_DESC"
    rm -f "$MOD_DIR/mirror" "$MOD_DIR/system"
done

rm -f "/data/adb/bloat_veil/logs/targets_bva.txt"
rm -f "/data/adb/post-fs-data.d/cleanup_bloat_veil.sh"
