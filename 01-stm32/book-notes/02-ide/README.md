# 第 2 章 集成开发环境介绍 —— 章节导航

> 书：第 2 章 集成开发环境介绍（原书 p16–26）
> 对应实验：`01-stm32/01-bare-metal/`（真机跑通：烧录 → 回读 → gdb 源码级停住，2026-09-26）

## 这一章在讲什么

书用 System Workbench for STM32 演示"IDE 怎么用"，
但**真正值钱的只有 2.2 一节**——它回答"IDE 到底替你做了什么"。

把这一节答清楚，IDE 就不是黑盒：换任何 IDE、或者根本不用 IDE，你都知道该敲什么。

## 小节清单

| 小节 | 标题 | 原书页 | 笔记 |
|---|---|---|---|
| 2.01 | 使用 STM32 的 System Workbench<br>├ 2.1.1 启动 IDE<br>├ 2.1.2 创建 Hello World<br>└ 2.1.3 调试程序 | 16–24 | [2.01-使用STM32的System-Workbench](2.01-使用STM32的System-Workbench.md) |
| 2.02 | **IDE 为我们做了什么** ⭐ | 24 | [2.02-IDE为我们做了什么](2.02-IDE为我们做了什么.md) |
| 2.03 | 导入本书的编程示例 | 25 | [2.03-导入本书的编程示例](2.03-导入本书的编程示例.md) |
| 2.04 | 总结 | 25 | [2.04-总结](2.04-总结.md) |
| 2.05 | 编程问题 | 26 | [2.05-编程问题](2.05-编程问题.md) |
| 2.06 | 其他问题 | 26 | [2.06-其他问题](2.06-其他问题.md) |

## 一句话总结本章

**IDE = 构建 + 烧录 + 调试 三条链路的按钮壳。** 三条链路各自的边界很清晰：

```
构建：.c/.S/.ld  →  make  →  .elf（调试用）+ .bin（烧录用）
烧录：.bin + 地址 →  openocd  →  Flash 里的字节
调试：.elf + 目标 →  openocd(server) + gdb(client)  →  断点/单步/变量
```

## 与书的差异

| 书 | 我 |
|---|---|
| System Workbench for STM32（SW4STM32） | **已停止维护**，不装。用 openocd + arm-none-eabi-gdb 等价替代 |
| 板子 NUCLEO-F030R8（Cortex-M0） | NUCLEO-F103RB（Cortex-M3），**GPIO 寄存器模型不同**（见 [2.03](2.03-导入本书的编程示例.md)） |
| 导入配套工程 | 自己手写启动文件/链接脚本/Makefile，写完再对照 |
| 调试用 IDE 图形界面 | gdb + openocd，**同样源码级**（实测停在 `main.c:38`） |

## 读完本章你应该能回答

- IDE 的 Debug 按钮按下后起了几个进程？跨几台设备？
- 为什么烧录用 `.bin`、调试用 `.elf`？
- `Error: init mode failed` 该按什么顺序排查？
- 296 字节的镜像为什么要擦 1 KiB？
- Cortex-M3 为什么只有 6 个硬件断点？

## 前置 / 后续

- 前置：[第 1 章 Hello World](../01-hello-world/README.md)——四步编译流程
- 后续：[第 3 章 嵌入式系统编程](../03-embedded-system-programming/README.md)——真正上板子
