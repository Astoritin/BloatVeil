#!/system/bin/sh
MODDIR=${0%/*}

CONFIG_DIR="/data/adb/bloat_veil"

MOD_DESC="A bloatware vanishing act on the system."
SEPARATE_LINE="********************************"

ROOT_FILE_MANAGERS="
com.speedsoftware.rootexplorer/com.speedsoftware.rootexplorer.RootExplorer
com.mixplorer/com.mixplorer.activities.BrowseActivity
bin.mt.plus/.Main
bin.mt.plus/bin.mt.plus.Main
com.lonelycatgames.Xplore/com.lonelycatgames.Xplore.Browser
com.ghisler.android.TotalCommander/com.ghisler.android.TotalCommander.MainActivity
pl.solidexplorer2/pl.solidexplorer.activities.MainActivity
com.amaze.filemanager/com.amaze.filemanager.activities.MainActivity
io.github.muntashirakon.AppManager/io.github.muntashirakon.AppManager.fm.FmActivity
io.github.muntashirakon.AppManager.debug/io.github.muntashirakon.AppManager.fm.FmActivity
nextapp.fx/nextapp.fx.ui.ExplorerActivity
me.zhanghai.android.files/me.zhanghai.android.files.filelist.FileListActivity
"

ecol() { echo "$SEPARATE_LINE"; }
ecoe() { echo " "; }

ecol
ecoe
echo "- BloatVeil
- By Astoritin"
ecoe
ecol
ecoe
echo "- $MOD_DESC"
ecoe
ecol
echo "- Opening config dir"
sleep 1

IFS=$'\n'

for fm in $ROOT_FILE_MANAGERS; do

    PKG=${fm%/*}

    if pm path "$PKG" >/dev/null 2>&1; then
        am start -n "$fm" "file://$CONFIG_DIR" >/dev/null 2>&1
        result_action="$?"
        echo "- Launching $PKG ($result_action)"
        if [ $result_action -eq 0 ]; then
            ecoe
            sleep 1
            return 0
        fi
    else
        echo "- $PKG is not installed"
    fi

done
