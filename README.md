# BloatVeil / 预装软件面纱
A bloatware vanishing act on the system / 预装软件，于系统启动时悄然隐去

## What is "BloatVeil"? / 什么是 “预装软件面纱”？
- A Magisk module for "removing" pre-installed APP(s) systemlessly.
- 一个不修改系统分区的前提下“移除”预装软件的 Magisk 模块。
- BloatVeil hides targeted pre-installed APP(s) during boot so system skips loading them.
- 在系统启动时，BloatVeil 将指定预装软件“掩盖在面纱下”，这样系统就不会加载它们。
- No pre-installed APP(s) are deleted: they just stay out of sight as booting system.
- 预装软件并没有被删除，只是让它们在系统扫描时“消失”。

## Supported Root Solution / 支持的 Root 方案
[Magisk](https://github.com/topjohnwu/Magisk) / [KernelSU](https://github.com/tiann/KernelSU) / [APatch](https://github.com/bmax121/APatch)   
- For KernelSU/APatch, you may need to flash [MetaModule](https://kernelsu.org/guide/metamodule.html) before flashing BloatVeil
- 对 KernelSU/APatch, 在刷入 BloatVeil 前你可能需要刷入[元模块](https://kernelsu.org/zh_CN/guide/metamodule.html)