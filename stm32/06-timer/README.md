# 06-timer —— SysTick 与通用定时器

> 状态：⬜ 未开始（骨架）。轨道一（裸机 C）第 6 个实验。
> 对应笔记：[补充 ch19 SysTick / 定时器](../../book-notes/19-systick-and-timer/README.md)（19.1–19.7 全篇）
> 前置：[04-uart-printf](../04-uart-printf/README.md)（串口观察）、
> [05-exti-button](../05-exti-button/README.md)（中断链路已通）

## 目标

- SysTick 配成 1 ms 心跳，维护 `g_ms` 毫秒计数（19.1–19.3 的路线）
- 用 `g_ms` 换掉 03 里那个空循环 `delay()`：精确 500 ms 闪灯
- 回绕安全的时间比较（19.3：`while ((now - t0) < 500)` 为什么对）
- 进阶（可拆第二次做）：TIM2 基础定时器 1 Hz 中断，与 SysTick 对账（19.5）

## 板上事实

- SysTick 是 **Cortex-M 内核外设**（不是 ST 的），寄存器在 `0xE000E010` 起，F0/F1/F4 都一样
- 时钟源可选 HCLK 或 HCLK/8；本实验默认 HSI 8 MHz → `LOAD = 8000-1` 得 1 ms
  （配了 PLL 72 MHz 后要改成 `72000-1`，见 ch21）
- F103 的 TIM2/TIM3 是 32/16 位通用定时器，挂在 APB1 上（注意 APB1 定时器时钟有 ×2 规则，ch21 会讲）

## 步骤

1. `SysTick->LOAD = 8000-1`；`VAL` 清零；`CTRL = CLKSOURCE | TICKINT | ENABLE`
2. `SysTick_Handler` 里 `g_ms++`（`volatile uint32_t`）
3. `delay_ms()` / 周期调度用「减法式」时间比较，**不用** `>=` 直接比
4. 主循环：500 ms 翻灯 + 每秒串口打一次 `g_ms`
5. 对账：让程序跑 10 分钟，比较 `g_ms` 与主机秒表，量化 HSI 的误差（HSI 是 RC，±1% 级别）

## 验收

- 闪灯周期秒表实测在 500 ms ± HSI 误差内
- `g_ms` 回绕实验（把初值设到接近 `UINT32_MAX`）：减法式比较依然正确，`>=` 式翻车——两组实测都贴出来
- TIM2 版（若做）：与 SysTick 漂移对比

## 坑点（待记）

- `LOAD` 是 24 位的：想 1 s 一次中断装不下（8 MHz 下最大约 2.1 s？——算一遍再写）
- 优化等级变化后空循环 `delay()` 全废（03 已经踩过），这就是本实验存在的理由
- HSI 温漂：同一固件冬天夏天频率不一样
