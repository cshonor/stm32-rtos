# freertos/book-notes —— 《Mastering the FreeRTOS Real Time Kernel》配套笔记

> 状态：🔨 **已开工**（2026-10-09）。章导航 12 章已齐；ch02/ch03 小节笔记已写满，
> 其余章小节随实验推进逐章补。
> 写作规范与 stm32/book-notes 相同：一小节一篇（50–120 行）、篇号与书章号对齐、
> 每篇带"原书怎么说 / 实测是什么"坑点表与折叠 Q&A、头部互链对应实验。
> ⚠ 实验 ⬜ 未做（stm32/01–06 未全通），现阶段笔记只讲机制，**实测数据待实验落地后补**。

## 配套教材

| 项 | 内容 |
|---|---|
| 首选 | **《Mastering the FreeRTOS Real Time Kernel: A Hands-On Tutorial Guide》**（Richard Barry，FreeRTOS 创始人） |
| 获取 | **官方免费 PDF**：[freertos.org 文档页](https://www.freertos.org/Documentation/RTOS_book.html)；官方仓库 [FreeRTOS/FreeRTOS-Kernel-Book](https://github.com/FreeRTOS/FreeRTOS-Kernel-Book)（Markdown 源） |
| 中译 | 社区译本：GitHub `brokensnow2/FreeRTOS-Kernel-Chinese-PDF`、`kashima19960/FreeRTOS-Kernel-Book-zh`。⚠ 非官方，API 行为以英文原版 + 源码为准 |
| 纸质备选 | 野火《FreeRTOS 内核实现与应用开发实战指南——基于STM32》（刘火良）——"第二视角"，讲内核实现 |
| 参考手册 | 《FreeRTOS Reference Manual》（API 逐条查阅，不精读） |

## 章节导航（官方章号）

| 章 | 主题 | 章导航 | 小节进度 | 对应实验 |
|---|---|---|---|---|
| ch01 | FreeRTOS 内核分发包 | [01-distribution](01-distribution/README.md) | ⬜ 0 篇 | 贯穿（移植取材） |
| ch02 | 堆内存管理 | [02-heap-memory](02-heap-memory/README.md) | ✅ **3 篇写满** | 贯穿（01 的 heap_4 选型） |
| ch03 | 任务管理 | [03-task-management](03-task-management/README.md) | ✅ **6 篇写满** | [01-hello-task](../01-hello-task/README.md) |
| ch04 | 队列管理 | [04-queue-management](04-queue-management/README.md) | ⬜ 0 篇 | [02-queue](../02-queue/README.md) |
| ch05 | 软件定时器管理 | [05-software-timers](05-software-timers/README.md) | ⬜ 0 篇 | 后续追加 |
| ch06 | 中断管理 | [06-interrupt-management](06-interrupt-management/README.md) | ⬜ 0 篇 | [03-semaphore](../03-semaphore/README.md)（二值信号量同步） |
| ch07 | 资源管理 | [07-resource-management](07-resource-management/README.md) | ⬜ 0 篇 | [04-mutex-priority](../04-mutex-priority/README.md) |
| ch08 | 事件组 | [08-event-groups](08-event-groups/README.md) | ⬜ 0 篇 | 后续追加 |
| ch09 | 任务通知 | [09-task-notifications](09-task-notifications/README.md) | ⬜ 0 篇 | 后续追加 |
| ch10 | 低功耗支持 | [10-low-power](10-low-power/README.md) | ⬜ 0 篇 | 后续追加 |
| ch11 | 开发者支持 | [11-developer-support](11-developer-support/README.md) | ⬜ 0 篇 | 工具向，随用随查 |
| ch12 | 故障排查 | [12-troubleshooting](12-troubleshooting/README.md) | ⬜ 0 篇 | 工具向，卡住时查 |

## 先行讲解

书之外的机制铺垫（PendSV/SysTick/双栈、超级循环的局限）在
[stm32/book-notes 补充 ch20 走向 FreeRTOS](../../stm32/book-notes/20-towards-freertos/README.md)——
**先读那三篇再进 ch03**，否则任务切换是黑盒。

- 回到：[freertos/README](../README.md) ｜ 仓库顶层：[README](../../README.md)
