# ch06 · 中断管理 —— 章节导航

> 书第 6 章 · 对应实验：[`02-freertos/03-semaphore`](../../03-semaphore/README.md)（⬜ 未做）
> 章导航：本篇

## 本章讲什么

**RTOS 世界里的中断纪律：ISR 要快走，慢活甩给任务——"延迟中断处理"
（deferred processing）的正规机制就是二值信号量。**本章回答：FromISR API 的
规则、`pxHigherPriorityTaskWoken` 与 `portYIELD_FROM_ISR` 的配合、
以及 Cortex-M 上 configMAX_SYSCALL_INTERRUPT_PRIORITY 这道"中断优先级红线"。

裸机篇 [ch10](../../../01-stm32/book-notes/10-interrupts/README.md) 的"上半部/下半部"
概念在这里正式落地：ISR = 上半部，被信号量唤醒的任务 = 下半部。

## 只看这一页（速览）

**主线一句话**：ISR 要快走、慢活甩给任务——6.1 立"二值信号量延迟中断处理"
三段式范式，6.2 提炼 FromISR 通用规则并讲透 yield 为什么必须手动放在 ISR
尾部，6.3 用 BASEPRI 划出中断优先级红线，6.4 用计数信号量解决丢事件和数
资源两类问题。

| 小节 | 一句话结论 |
|---|---|
| 6.1 二值信号量中断同步 | 范式 = ISR 清标志 + give + yield、任务 take + 干活；只报信用二值信号量，要带数据用队列 |
| 6.2 FromISR 规则与 yield | ISR 只碰 FromISR API 且永不阻塞；yield 手动放尾部、一批 API 只切一次，不 yield 最多白等一个 tick |
| 6.3 中断优先级红线 | 数值 ≥ `configMAX_SYSCALL_INTERRUPT_PRIORITY` 才能调 FromISR；临界区用 BASEPRI 部分屏蔽，裸奔段不被拖延 |
| 6.4 计数信号量 | 一个 0..N 计数器撑起数资源（初值 = max）与数事件（初值 = 0）；max 内积压不丢，超出照样丢 |

**本章最容易踩的坑**

- 任务/中断两套优先级数字方向相反，写 `FreeRTOSConfig.h` 时最容易串（6.3）
- 红线上方的 ISR 偷调 API = 并发改内核名单，不立刻死、攒到某次调度才崩，最难查（6.3）
- 忘记 ISR 尾部 `portYIELD_FROM_ISR`：被唤醒的高优先级任务白等一个 tick（6.2）
- "次数就是信息"的场景用二值信号量会丢事件，该用计数信号量（6.1/6.4）
- 数资源时 give 返回 `pdFAIL` = 借还配平的代码有 bug，开发期建议断言当场抓（6.4）

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [6.1 二值信号量中断同步](6.1-二值信号量中断同步.md) | 延迟中断处理的标准范式 | ✅ |
| [6.2 FromISR 规则与 yield](6.2-FromISR规则与yield.md) | pxHigherPriorityTaskWoken 机制 | ✅ |
| [6.3 中断优先级红线](6.3-中断优先级红线.md) | configMAX_SYSCALL_INTERRUPT_PRIORITY 与 PRIMASK/BASEPRI | ✅ |
| [6.4 计数信号量](6.4-计数信号量.md) | 资源计数与事件计数（丢事件问题） | ✅ |

## 读完本章你应该能回答

- 为什么 ISR 里不能阻塞？为什么 ISR 里能调 `xSemaphoreGiveFromISR`？
- `xHigherPriorityTaskWoken` 为 pdTRUE 后为什么还要手动 `portYIELD_FROM_ISR`？
- 优先级数值 ≥ configMAX_SYSCALL_INTERRUPT_PRIORITY 的中断为什么不能调任何 RTOS API？
  （Cortex-M 优先级数字越小越高的老坑再现）
- 二值信号量和计数信号量在"事件来的比处理快"时行为差在哪？

## 前置 / 后续

- **前置**：[01-stm32/book-notes ch10 中断](../../../01-stm32/book-notes/10-interrupts/README.md)
  （NVIC/EXTI/优先级分组）+ [ch04 队列](../04-queue-management/README.md)
- **后续**：[ch07 资源管理](../07-resource-management/README.md)（信号量的另一半：
  互斥量与优先级继承）→ 实验 [`02-freertos/03-semaphore`](../../03-semaphore/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测数据 | 实验 03 未做；届时用按键 EXTI + 二值信号量补实测（含去抖对照书 ch05） |
