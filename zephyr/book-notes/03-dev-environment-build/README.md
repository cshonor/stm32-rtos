# ch03 · 开发环境与构建原理 —— 章节导航

> 书第 3 章 · 对应实验：[`zephyr/01-hello`](../../01-hello/README.md)（⬜ 骨架已建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的"三件套"——west（仓库与构建编排）、Kconfig（功能配置）、
devicetree（硬件描述）——如何合力把一个应用编出来。**
这是 Zephyr 学习曲线最陡的一段，也是它和 FreeRTOS 工程形态的最大差异：
FreeRTOS 是"把几个 .c 加进你的 Makefile"，Zephyr 是"把你的应用挂进它的构建系统"。

与 LDD- 侧的关联直接拉满：Kconfig 和 devicetree 就是 Linux 内核的同一套机制
（`LDD-/09` 设备树章），语法零迁移成本。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 3.1 | west：manifest、init/update、build/flash/debug 一条链 | ⬜ |
| 3.2 | 一个 Zephyr 应用的最小骨架：CMakeLists.txt + prj.conf + app.overlay | ⬜ |
| 3.3 | Kconfig 怎么工作：prj.conf → autoconf.h；menuconfig 看什么 | ⬜ |
| 3.4 | 构建产物解剖：zephyr.elf / merged.hex / build 目录里都有啥 | ⬜ |

## 读完本章你应该能回答

- `west build -b nucleo_f103rb app` 背后依次发生了哪几步？
- prj.conf 里 `CONFIG_GPIO=y` 最终怎么变成代码里的 `#define`？
- 应用级的 devicetree overlay 是怎么"叠"到板级 dts 上的？
- 为什么 Zephyr 工程不该手写顶层 Makefile？

## 前置 / 后续

- **前置**：[stm32/book-notes ch11 链接器../../../stm32/book-notes/11-linker/README.md)
  （构建的终点还是链接脚本和段布局，底子在裸机篇）
- **后续**：[ch04 多线程](../04-multithreading/README.md)（实验 01 的理论）→
  [ch09 DeviceTree](../09-devicetree/README.md)（三件套里最深的那个）

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写 | 等 01-hello 实验落地时写——届时有真实构建日志可解剖 |
| 书基于 2024 工具链 | west/Zephyr SDK 版本差异以官方文档为准 |
