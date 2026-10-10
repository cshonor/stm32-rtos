# 05-exti-button —— 按键中断（EXTI + NVIC）

> 状态：⬜ 未开始（骨架）。轨道一（裸机 C）第 5 个实验。
> 对应笔记：[第 10 章 中断](../book-notes/10-interrupts/README.md)（全章）
> + [第 5 章 决策和控制语句](../book-notes/05-control-flow-button/README.md)（按钮硬件、上拉/下拉、去抖）
> 前置：[03-gpio-blink](../03-gpio-blink/README.md)（✅ 真机实测）、
> 建议先有 [04-uart-printf](../04-uart-printf/README.md)（用串口观察中断行为）

## 目标

- 用户按键 B1（**PC13**）接 EXTI13，中断里翻转 LED，主循环什么都不干
- 把「轮询 vs 中断」在同一功能上做对照（10.01 的主题）
- 按键计数通过 04 的串口打印出来：主循环读计数，ISR 写计数（单写者，呼应 10.5 环形缓冲的并发纪律）

## 板上事实

- NUCLEO-F103RB 用户按键 **B1 = PC13**（按下 = 高电平，外部有下拉）；蓝色按钮
- EXTI13 属于 `EXTI15_10_IRQn` 合并中断（F1 上 EXTI10–15 共用一个向量）
- 开 EXTI 前要先开 **AFIO 时钟**并把 EXTICR 的端口选到 GPIOC——F1 特有步骤，F0/F4 不同

## 步骤

1. 开时钟：GPIOC + AFIO
2. PC13 配输入（03 里已用 PC13 做过轮询读数，寄存器账可直接抄）
3. AFIO EXTICR4 把 EXTI13 映射到 PC；EXTI_IMR 开 13 线、FTSR 选边沿
4. NVIC：`NVIC_EnableIRQ(EXTI15_10_IRQn)`（裸写就是 `NVIC_ISER1` 对应位）
5. ISR：`EXTI15_10_IRQHandler` 里 **w1c 清 PR**（写 1 清除，10.04 有坑点表），翻转 LED、计数 +1
6. 主循环：`for(;;)` 里串口慢速打印计数

## 验收

- 按一下灯翻一次，串口计数 +1（对照「没清 PR → 中断风暴」的反面实测）
- 用 gdb 在 ISR 下断点确认硬件压栈（10.03 的 8 字帧）真实发生
- 实测输出贴进本 README

## 坑点（待记）

- 忘清 `EXTI_PR` → ISR 反复进（w1c 语义）
- 忘开 AFIO 时钟 → EXTI 永远不触发，且寄存器读了像正常的
- 机械抖动：一次按下多次进 ISR —— 去抖留给 02-freertos/03（二值信号量版）对照
