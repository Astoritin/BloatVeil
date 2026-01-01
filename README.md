# BloatVeil / 预装软件面纱
A bloatware vanishing act on the system / 预装软件，于系统启动时悄然隐去

## What is "BloatVeil"? / 什么是 “预装软件面纱”？
- A Magisk module for "removing" pre-installed APP(s) systemlessly.
- BloatVeil hides targeted pre-installed APP(s) during boot so system skips loading them.
- No pre-installed APP(s) are deleted: they just stay out of sight as booting system.
   
- 一个不修改系统分区的前提下“移除”预装软件的 Magisk 模块。
- 在系统启动时，BloatVeil 将指定预装软件“掩盖在面纱下”，这样系统就不会加载它们。
- 预装软件并没有被删除，只是让它们在系统扫描时“消失”。

## Supported Root Solution / 支持的 Root 方案
- [Magisk](https://github.com/topjohnwu/Magisk) - Recommend!/推荐！
- [KernelSU](https://github.com/tiann/KernelSU)
- [APatch](https://github.com/bmax121/APatch)   
   
- For KernelSU/APatch, you may need to flash [MetaModule](https://kernelsu.org/guide/metamodule.html) before flashing BloatVeil
- 对 KernelSU/APatch, 在刷入 BloatVeil 前你可能需要刷入[元模块](https://kernelsu.org/zh_CN/guide/metamodule.html)

## Steps / 步骤

- Flash BloatVeil, the steps is just like how do you flash other Magisk modules.
- Use [App Manager](https://github.com/MuntashirAkon/AppManager) to search for the pre-installed app names you want to "remove".
- Open the app details page and copy its source directory.
> Use Root Explorer, MT Manager or MiXplorer to manually locate and copy the directory names of pre-installed apps under `/system` is okay too.
- Open the file `/data/adb/bloat_veil/targets.txt` and paste the bloatwares directories, **one per line**.
- Save the changes to `targets.txt` and reboot your device to observe the results.
   
> For example, I need to uninstall XiaoAi Voice Assistant, so I will get the directory XiaoAi Voice Assistant located in by AppManager and soon get its name `VoiceAssistAndroidT`, then copy `VoiceAssistAndroidT` and add it into `targets.txt` , save the changes and reboot my device.
   
- 刷入 BloatVeil ，步骤跟你刷入其他 Magisk 模块的操作一样
- 打开 [App Manager](https://github.com/MuntashirAkon/AppManager) 以查找你想“移除”的预装软件名称
- 打开应用详情页面并复制其来源目录
> 你也可以通过 Root Explorer, MT管理器 或 MiXplorer 自行定位和复制位于 `/system` 下预装软件的目录名
- 打开配置文件 `/data/adb/bloat_veil/targets.txt` 并粘贴这些目录名，**一行一个**
- 保存 `targets.txt` 的改动并重新启动你的设备以观察结果
