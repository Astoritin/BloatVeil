# BloatVeil
BloatVeil, a bloatware vanishing act on the system   
BloatVeil, 一个针对系统的预装软件们的消失戏法（预装软件，于系统启动时悄然隐去）   
## What is "BloatVeil"? / 什么是 “预装软件面纱”？
- A Magisk module for "removing" pre-installed APP(s) systemlessly.
- BloatVeil hides targeted pre-installed APP(s) during boot so system skips loading them.
- _No pre-installed APP(s) are deleted: they just stay out of sight as booting system._
***
- 一个不修改系统分区的前提下“移除”预装软件的 Magisk 模块。
- 在系统启动时，BloatVeil 将指定预装软件“掩盖在面纱下”，这样系统就不会加载它们。
- *预装软件并没有被删除，它们只是在系统扫描时中“不在扫描清单里了”。*   
## Supported Root Solution / 支持的 Root 方案
- [Magisk](https://github.com/topjohnwu/Magisk) (Recommend!/推荐!)
- [KernelSU](https://github.com/tiann/KernelSU)
- [APatch](https://github.com/bmax121/APatch)   
   
***KernelSU/APatch : You may need to flash [MetaModule](https://kernelsu.org/guide/metamodule.html) before flashing BloatVeil***   
***对于 KernelSU/APatch: 在刷入 BloatVeil 前你可能需要刷入[元模块](https://kernelsu.org/zh_CN/guide/metamodule.html)***   
## Help Documents / 帮助文档
**See [here](https://github.com/Astoritin/BloatVeil/wiki)** / **参阅 [此处](https://github.com/Astoritin/BloatVeil/wiki)**

## Credits / 鸣谢
- [Magisk](https://github.com/topjohnwu/Magisk) - the foundation which makes everything possible
- [Zygisk Next](https://github.com/Dr-TSNG/ZygiskNext) - the implementation of function extract and root solution check
- [LSPosed](https://github.com/LSPosed/LSPosed) - the implementation of function extract and root solution check