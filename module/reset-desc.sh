#!/system/bin/sh

if [ -f "/data/adb/modules/bloat_veil/disable" ]; then
    sed -i 's/^description=.*/description=A bloatware vanishing act on the system./' "/data/adb/modules/bloat_veil/module.prop"
    rm -f "/data/adb/post-fs-data.d/reset-desc.sh"
fi
