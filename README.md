# BloatVeil / 预装软件面纱
A bloatware vanishing act on the system / 预装软件，于系统启动时悄然隐去
## What is "BloatVeil"? / 什么是 “预装软件面纱”？
- A Magisk module for "removing" pre-installed APP(s) systemlessly.
- BloatVeil hides targeted pre-installed APP(s) during boot so system skips loading them.
- No pre-installed APP(s) are deleted: they just stay out of sight as booting system.
***
- 一个不修改系统分区的前提下“移除”预装软件的 Magisk 模块。
- 在系统启动时，BloatVeil 将指定预装软件“掩盖在面纱下”，这样系统就不会加载它们。
- 预装软件并没有被删除，只是让它们在系统扫描时“消失”。
## Supported Root Solution / 支持的 Root 方案
- [Magisk](https://github.com/topjohnwu/Magisk) (Recommend!/推荐!)
- [KernelSU](https://github.com/tiann/KernelSU)
- [APatch](https://github.com/bmax121/APatch)   
   
*For KernelSU/APatch, you may need to flash [MetaModule](https://kernelsu.org/guide/metamodule.html) before flashing BloatVeil*   
*对 KernelSU/APatch, 在刷入 BloatVeil 前你可能需要刷入[元模块](https://kernelsu.org/zh_CN/guide/metamodule.html)*
## Steps / 步骤
- Flash BloatVeil, the steps is just like how do you flash other Magisk modules.
- Use [App Manager](https://github.com/MuntashirAkon/AppManager) to search for the pre-installed app names you want to "remove".
- Open the app details page and copy its source directory.
> Use Root Explorer, MT Manager or MiXplorer to manually locate and copy the directory names of pre-installed apps under `/system` is okay too.
- Open the file `/data/adb/bloat_veil/targets.txt` and paste the bloatwares directories, **one per line**.
- Save the changes to `targets.txt` and reboot your device to observe the results.   
   
_For example, I need to uninstall XiaoAi Voice Assistant, so I will get the directory XiaoAi Voice Assistant located in by AppManager and soon get its name `VoiceAssistAndroidT`, then copy `VoiceAssistAndroidT` and add it into `targets.txt` , save the changes and reboot my device._
***
- 刷入 BloatVeil ，步骤跟你刷入其他 Magisk 模块的操作一样
- 打开 [App Manager](https://github.com/MuntashirAkon/AppManager) 以查找你想“移除”的预装软件名称
- 打开应用详情页面并复制其来源目录
> 你也可以通过 Root Explorer, MT管理器 或 MiXplorer 自行定位和复制位于 `/system` 下预装软件的目录名
- 打开配置文件 `/data/adb/bloat_veil/targets.txt` 并粘贴这些目录名，**一行一个**
- 保存 `targets.txt` 的改动并重新启动你的设备以观察结果   
   
_例如：我需要卸载小爱同学，那么我会通过 AppManager 查看小爱同学所在的文件夹，得知其名字是 VoiceAssistAndroidT，然后将 VoiceAssistAndroidT 复制到 targets.txt ，回车并保存更改后重启设备。_
## Notes / 注意
1. `targets.txt` supports commenting out entire lines with the "#" symbol. BloatVeil will ignore commented lines and empty lines.
2. BloatVeil supports custom paths, for example: `/system/app/MiVideo`. In this case, BloatVeil will directly process the custom path without scanning other system directories.
3. To save the time and reduce the cost of resources, now BloatVeil will update the items of `targets.txt` into the system path bloatwares located in automatically in each time booting. You can read the chapter `Config File` to know.
4. If the resource directory starts with `/data`, it means the app was installed as first booting after the initial of ROM setup. You can uninstall it manually and should NOT add it to `targets.txt`, as BloatVeil's processing will not affect such apps.
***
1. `targets.txt` 支持"#"号注释整行和项目旁存在注释，BloatVeil 不会处理被注释掉的行和空行。
2. BloatVeil 支持自定义路径，例如：`/system/app/MiVideo`。此时 BloatVeil 会直接处理该自定义路径而不会再扫描其他系统文件夹。
3. 为了节省时间和减少资源消耗，现在`targets.txt`会随着每次系统启动自动更新为预装APP对应的系统目录，你可以查阅“配置文件”部分进行了解。
4. 若你看到的资源目录以 `/data` 开头，则说明该APP是安装完ROM后的第一次初始化安装上的，实质上属于用户应用，只是内置于ROM的刷机包的特定目录。这类应用可以自行卸载，并且只有恢复出厂设置时才可能重新被自动安装，请不要加入到 `targets.txt` 中，因为BloatVeil的处理也不会对这类软件生效。
