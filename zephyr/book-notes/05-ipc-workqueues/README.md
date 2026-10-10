# ch05 · 消息队列 / 管道 / 邮箱 / workqueue —— 章节导航

> 书第 5 章 · 对应实验：[`zephyr/02-threads-msgq`](../../02-threads-msgq/README.md)（⬜ 骨架已建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的线程间通信工具箱比 FreeRTOS 丰富得多：k_msgq（≈FreeRTOS 队列）、
k_pipe（字节流）、k_mbox（带优先级的邮箱）、k_fifo/k_lifo（链表传递）、
以及 Linux 风格的 workqueue（延迟工作项）。**本章的核心问题是
"什么场景选哪个"——工具多，选错比不会用更常见。

对照 [freertos/book-notes ch04../../../freertos/book-notes/04-queue-management/README.md)：
FreeRTOS 一个 queue 打天下；Zephyr 按语义细分出五六种对象。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 5.01 | k_msgq：与 FreeRTOS queue 的逐项对照 | ⬜ |
| 5.02 | k_pipe 与 k_fifo/k_lifo：字节流 vs 指针传递 | ⬜ |
| 5.03 | k_mbox 邮箱：带优先级排序的消息 | ⬜ |
| 5.04 | workqueue：Zephyr 的"下半部"，k_work / k_work_delayable | ⬜ |

## 读完本章你应该能回答

- k_msgq 和 FreeRTOS queue 在"传值/传指针、阻塞语义、ISR 可用性"上的异同？
- workqueue 和 FreeRTOS 的"守护任务+命令队列"（软件定时器那套）是什么关系？
- k_work_delayable 和 FreeRTOS 软件定时器怎么对应？取消语义呢？
- 中断里交活，为什么 Zephyr 惯用 k_work_submit 而 FreeRTOS 惯用 xQueueSendFromISR？

## 前置 / 后续

- **前置**：[ch04 多线程](../04-multithreading/README.md)
  + [freertos/book-notes ch04 队列../../../freertos/book-notes/04-queue-management/README.md)
- **后续**：[ch09 DeviceTree](../09-devicetree/README.md)（驱动里到处是 workqueue）

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写 | 实验 02 未做；届时与 freertos/02-queue 做对照实测 |
