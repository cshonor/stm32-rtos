# ch06 · 中断管理 —— 章节导航

> 书第 6 章 · 对应实验：[`freertos/03-semaphore`](../../03-semaphore/README.md)（⬜ 未做）
> 章导航：本篇

## 本章讲什么

**RTOS 世界里的中断纪律：ISR 要快走，慢活甩给任务——"延迟中断处理"
（deferred processing）的正规机制就是二值信号量。**本章回答：FromISR API 的
规则、`pxHigherPriorityTaskWoken` 与 `portYIELD_FROM_ISR` 的配合、
以及 Cortex-M 上 configMAX_SYSCALL_INTERRUPT_PRIORITY 这道"中断优先级红线"。

裸机篇 [ch10](../../../stm32/book-notes/10-interrupts/README.md) 的"上半部/下半部"
概念在这里正式落地：ISR = 上半部，被信号量唤醒的任务 = 下半部。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 6.1 | 二值信号量做中断同步：延迟中断处理的标准范式 | ⬜ |
| 6.2 | FromISR 规则与 pxHigherPriorityTaskWoken 机制 | ⬜ |
| 6.3 | 中断优先级红线：configMAX_SYSCALL_INTERRUPT_PRIORITY 与 PRIMASK/BASEPRI | ⬜ |
| 6.4 | 计数信号量：资源计数与事件计数（丢事件问题） | ⬜ |

## 读完本章你应该能回答

- 为什么 ISR 里不能阻塞？为什么 ISR 里能调 `xSemaphoreGiveFromISR`？
- `xHigherPriorityTaskWoken` 为 pdTRUE 后为什么还要手动 `portYIELD_FROM_ISR`？
- 优先级数值 ≥ configMAX_SYSCALL_INTERRUPT_PRIORITY 的中断为什么不能调任何 RTOS API？
  （Cortex-M 优先级数字越小越高的老坑再现）
- 二值信号量和计数信号量在"事件来的比处理快"时行为差在哪？

## 前置 / 后续

- **前置**：[stm32/book-notes ch10 中断](../../../stm32/book-notes/10-interrupts/README.md)
  （NVIC/EXTI/优先级分组）+ [ch04 队列](../04-queue-management/README.md)
- **后续**：[ch07 资源管理](../07-resource-management/README.md)（信号量的另一半：
  互斥量与优先级继承）→ 实验 [`freertos/03-semaphore`](../../03-semaphore/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写 | 实验 03 未做；届时用按键 EXTI + 二值信号量补实测（含去抖对照书 ch05） |
