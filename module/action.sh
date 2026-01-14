#!/system/bin/sh

CONFIG_DIR="/data/adb/bloat_veil"

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

IFS=$'\n'

for rfm in $ROOT_FILE_MANAGERS; do

    PKG=${rfm%/*}

    if pm path "$PKG" >/dev/null 2>&1; then
        am start -n "$rfm" "file://$CONFIG_DIR" >/dev/null 2>&1
        if [ "$?" -eq 0 ]; then
            return 0
        fi
    fi

done
