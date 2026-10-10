# ch04 · 多线程 —— 章节导航

> 书第 4 章 · 对应实验：[`zephyr/01-hello`](../../01-hello/README.md)（⬜ 骨架已建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的线程模型：k_thread 是什么、两种创建方式、
最有特色的一点——优先级分"协作式（负数）"和"抢占式（非负）"两个世界。**
与 [freertos/book-notes ch03../../../freertos/book-notes/03-task-management/README.md)
对照着读：机制同源，词汇和默认值差异很大。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 4.01 | 线程是什么：k_thread、TCB 与栈 | [4.01-线程是什么](4.01-线程是什么.md) |
| 4.02 | 创建线程两法：k_thread_create vs K_THREAD_DEFINE | [4.02-创建线程两法](4.02-创建线程两法.md) |
| 4.03 | 优先级两个世界：协作式负数 vs 抢占式非负 | [4.03-优先级两个世界](4.03-优先级两个世界.md) |
| 4.04 | 调度与睡眠：k_sleep / k_yield / k_wakeup | [4.04-调度与睡眠](4.04-调度与睡眠.md) |
| 4.05 | 系统线程：main 线程与 idle 线程 | [4.05-系统线程](4.05-系统线程.md) |
| 4.06 | 生命周期：join / abort 与栈溢出检测 | [4.06-生命周期与栈检测](4.06-生命周期与栈检测.md) |

## 读完本章你应该能回答

- `K_THREAD_DEFINE` 和 `k_thread_create` 的本质区别？（静态 vs 动态分配）
- 为什么协作式线程（负优先级）永远不会被抢占？它和 FreeRTOS 的什么概念对应？
- `k_sleep(K_MSEC(100))` 和 FreeRTOS 的 vTaskDelay 语义一样吗？
- main() 在 Zephyr 里跑在什么上下文？优先级多少？
- Zephyr 里"周期任务不漂移"靠什么？（对照 FreeRTOS 的 vTaskDelayUntil）

## 前置 / 后续

- **前置**：[freertos/book-notes ch03 任务管理../../../freertos/book-notes/03-task-management/README.md)
  （机制同源，先学 FreeRTOS 版再换词）
- **后续**：[ch05 队列/管道/邮箱/workqueue](../05-ipc-workqueues/README.md)
  → 实验 [`zephyr/01-hello`](../../01-hello/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测输出 | 实验 01 未做（west 环境未建）；数据待落地后补 |
| 书 API 与新版有差 | 已按官方文档校正（如 k_usleep、k_busy_wait 现行行为） |
| SMP 只提了一句 | 书有专门节；F103 单核用不上，需要时补 |
