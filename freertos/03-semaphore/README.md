# 03-semaphore —— 二值信号量做按键去抖

> 状态：⬜ 未开始（骨架）。
> 对应笔记：[补充 ch20](../../book-notes/20-towards-freertos/README.md)（20.2）
> + [第 5 章](../../book-notes/05-control-flow-button/README.md)（机械抖动、去抖三做法）
> 前置：01-hello-task、stm32/05-exti-button（EXTI 中断链路）
> 对照：zephyr/03-semaphore（k_sem 版）

## 目标

- EXTI13（B1 = PC13）ISR 里 `xSemaphoreGiveFromISR`，任务里 `xSemaphoreTake` 阻塞等键
- 去抖策略用「ISR 只给一次信号量，任务take 后 `vTaskDelay(20ms)` 内忽略后续」——
  和第 5 章的三种去抖（硬件 RC / 轮询计数 / 定时器）做第四种的对比

## 步骤

1. `xSemaphoreCreateBinary()`；EXTI ISR 里 give
2. 任务：take → 确认电平仍有效 → 计为一次按键 → delay 去抖窗
3. 量化：串口打印「中断次数 vs 有效按键次数」的比值——抖动的实测量化

## 验收

- 不按不触发、按一次计一次（连按 20 次统计误差）
- 抖动比值实测数据（无去抖时 ISR 次数 / 去抖后按键次数）贴进本 README

## 坑点（待记）

- 二值信号量会「合并」：去抖窗内多次 give 只存一个——这正是用它去抖的原理，但也意味着
  想统计「原始中断次数」得另用计数变量
- `xSemaphoreGiveFromISR` 也有 `pxHigherPriorityTaskWoken` 问题（同 02-queue 的坑）
