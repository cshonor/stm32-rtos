# freertos/book-notes —— 《Mastering the FreeRTOS Real Time Kernel》配套笔记

> 状态：⬜ **骨架**（2026-10-09 建）。启动条件：stm32/01–06 真机全通 + 读完
> [stm32/book-notes 补充 ch20](../../stm32/book-notes/20-towards-freertos/README.md)。
> 写作规范与 stm32/book-notes 相同：一小节一篇（50–120 行）、篇号与书章号对齐、
> 每篇带"原书怎么说 / 实测是什么"坑点表与折叠 Q&A、头部互链对应实验。

## 配套教材（2026-10-09 调研）

| 项 | 内容 |
|---|---|
| 首选 | **《Mastering the FreeRTOS Real Time Kernel: A Hands-On Tutorial Guide》**（Richard Barry，FreeRTOS 创始人） |
| 获取 | **官方免费 PDF**：[freertos.org 文档页](https://www.freertos.org/Documentation/RTOS_book.html)；官方仓库 [FreeRTOS/FreeRTOS-Kernel-Book](https://github.com/FreeRTOS/FreeRTOS-Kernel-Book)（Markdown 源） |
| 中译 | 社区译本两份：GitHub `brokensnow2/FreeRTOS-Kernel-Chinese-PDF`（V1.1.0 全 13 章，带书签 PDF）、`kashima19960/FreeRTOS-Kernel-Book-zh`（mkdocs 在线版）。⚠ 均非官方，API 行为以英文原版 + 源码为准 |
| 章节 | 前言 + 13 章：内核分发包 / 堆内存 / 任务 / 队列 / 软件定时器 / 中断 / 资源管理 / 事件组 / 任务通知 / 低功耗 / 开发者支持 / 故障排查 |
| 纸质备选 | 野火《FreeRTOS 内核实现与应用开发实战指南——基于STM32》（刘火良，机械工业出版社）——基于 STM32 讲内核实现，与本仓库硬件完全对口，适合做"第二视角" |
| 参考手册 | 《FreeRTOS Reference Manual》（官方，API 逐条查阅，不精读） |

## 章节 → 实验对位（规划）

| 书章节 | 对应实验 | 状态 |
|---|---|---|
| ch04 任务管理 | [../01-hello-task](../01-hello-task/README.md) | ⬜ 骨架已建 |
| ch05 队列管理 | [../02-queue](../02-queue/README.md) | ⬜ 骨架已建 |
| ch07 资源管理（信号量） | [../03-semaphore](../03-semaphore/README.md) | ⬜ 骨架已建 |
| ch07 互斥量 + 优先级继承 | [../04-mutex-priority](../04-mutex-priority/README.md) | ⬜ 骨架已建 |
| ch03 堆内存管理 | 贯穿（heap_4.c 选型在 01 里定） | — |
| ch06 软件定时器 / ch08 事件组 / ch09 任务通知 | 后续追加实验 | ⬜ 未规划 |

- 回到：[freertos/README](../README.md) ｜ 仓库顶层：[README](../../README.md)
