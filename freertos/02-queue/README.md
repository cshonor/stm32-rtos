# 02-queue —— 中断 → 队列 → 任务（下半部思想的 RTOS 版）

> 状态：⬜ 未开始（骨架）。
> 对应笔记：[补充 ch20](../../stm32/book-notes/20-towards-freertos/README.md)（20.2 队列与信号量：
> ISR ↔ 任务之间怎么传数据）+ [第 10 章中断](../../stm32/book-notes/10-interrupts/README.md)（10.5 环形缓冲）
> 前置：01-hello-task、stm32/04-uart-printf（串口中断收）
> 对照：LDD-/09 中断下半部；zephyr/02-threads-msgq（k_msgq 版）

## 目标

- USART2 接收中断里**只**做 `xQueueSendFromISR`，数据处理全在任务里
- 和 10.5 的手写环形缓冲做正面对照：同一件事，RTOS 替你封装了什么、代价是什么

## 步骤

1. 建队列：`xQueueCreate(64, sizeof(uint8_t))`（对照 10.5 的 `RB_SIZE 64`）
2. USART2 ISR：`RXNE` → 读 `DR` → `xQueueSendFromISR(q, &c, &woken)` →
   `portYIELD_FROM_ISR(woken)`
3. 任务：`xQueueReceive(q, &c, portMAX_DELAY)` 阻塞等字节，收到后处理（回显 + 行缓冲命令解析）
4. 观察点：ISR 里**不能**调非 `FromISR` 的 API——故意写错一次，看 assert/HardFault 长什么样

## 验收

- 主机连续发 64+ 字节不丢（队列满时的行为也测：丢 or 覆盖？把选择写出来）
- 与 10.5 环形缓冲版对账：代码行数、`.text` 增量、CPU 占用（串口打 `uxTaskGetSystemState` 或 tick 差）
- 实测输出贴进本 README

## 坑点（待记）

- `FromISR` 系列不会阻塞——队列满直接失败返回，和任务版语义不同
- `pxHigherPriorityTaskWoken` 忘了用 → 被唤醒的高优先级任务要等到下一个 tick 才跑（延迟一个 tick 的实测证据）
