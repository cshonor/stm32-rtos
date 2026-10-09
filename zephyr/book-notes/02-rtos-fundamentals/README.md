# ch02 · RTOS 基础复习 —— 章节导航

> 书第 2 章 · 对应实验：与 [`freertos/01–04`../../../freertos/README.md) 概念对照
> 章导航：本篇

## 本章讲什么

**把 RTOS 通用概念（任务、调度、抢占、优先级反转、IPC）用 Zephyr 的词汇
重新讲一遍。**对本仓库的读者这章是"复习 + 换词表"：
机制在 [stm32/book-notes ch20../../../stm32/book-notes/20-towards-freertos/README.md)
和 [freertos/book-notes ch03../../../freertos/book-notes/03-task-management/README.md)
已经学过，这里重点是**同一件事在 Zephyr 里叫什么名字**。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 2.1 | 词汇对照表：task→thread、queue→msgq、semaphore→k_sem…… | ⬜ |
| 2.2 | 优先级体系的世界观差异：FreeRTOS 正数向上 vs Zephyr 负数协作 | ⬜ |
| 2.3 | 确定性、 deadlines 与"实时"到底承诺什么 | ⬜ |

## 读完本章你应该能回答

- FreeRTOS 的任务优先级和 Zephyr 的线程优先级，数字方向各是什么样？
- "协作式线程"在 Zephyr 里是一等公民，FreeRTOS 里为什么没有对应物？
- 同一个优先级反转剧本，在两个内核里的解药分别叫什么？

## 前置 / 后续

- **前置**：[freertos/book-notes ch03 任务管理../../../freertos/book-notes/03-task-management/README.md)
- **后续**：[ch03 开发环境与构建原理](../03-dev-environment-build/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写 | 2.1 词汇对照表随 ch04–ch05 笔记自然形成后回填更准 |
