# ch04 · 队列管理 —— 章节导航

> 书第 4 章 · 对应实验：[`02-freertos/02-queue`](../../02-queue/README.md)（⬜ 未做）
> 章导航：本篇

## 本章讲什么

**队列是 FreeRTOS 里任务与任务、ISR 与任务之间传数据的唯一正规通道。**
本章回答：队列内部长什么样（环形缓冲 + 两个阻塞名单）、收发时的阻塞语义、
以及为什么传大结构体要传指针而不是传值。

裸机篇 [ch10.5 环形缓冲](../../../01-stm32/book-notes/10-interrupts/README.md) 手写过一个
ISR→主循环的 ring buffer；FreeRTOS 队列就是那个思路的**带阻塞语义的正式版**。

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [4.1 队列是什么](4.1-队列是什么.md) | FIFO 环形缓冲 + 值拷贝语义 | ✅ |
| [4.2 阻塞语义与超时](4.2-阻塞语义与超时.md) | xTicksToWait 三态、唤醒顺序 | ✅ |
| [4.3 FromISR 家族](4.3-FromISR家族.md) | ISR 专用 API 与 pxHigherPriorityTaskWoken | ✅ |
| [4.4 传指针的代价与规矩](4.4-传指针的代价与规矩.md) | 大结构体、所有权、xQueueOverwrite | ✅ |
| [4.5 队列集](4.5-队列集.md) | xQueueSelectFromSet 并集阻塞（实验 03 对位） | ✅ |

## 读完本章你应该能回答

- 队列满时发送方有哪三种选择？（参数 xTicksToWait 的三种取值）
- 队列为什么既存数据又存两个"等待名单"？（读空名单 / 写满名单）
- `xQueueSendFromISR` 为什么不能阻塞？`pxHigherPriorityTaskWoken` 是干什么的？
- 覆盖式队列（长度 1 + xQueueOverwrite）和普通队列分别适合什么数据？
- 给队列发一个指向局部变量的指针，错在哪？

## 前置 / 后续

- **前置**：[ch03 任务管理](../03-task-management/README.md)（Blocked 态就是队列语义的燃料）
  + [ch20.2 队列与信号量](../../../01-stm32/book-notes/20-towards-freertos/20.2-队列与信号量.md)
- **后续**：[ch06 中断管理](../06-interrupt-management/README.md)（ISR 下半部的正规做法）
  → 实验 [`02-freertos/02-queue`](../../02-queue/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节无实测数据 | 实验 02/03 未做；届时对照"手写 ring buffer vs xQueue"补实测对比 |
