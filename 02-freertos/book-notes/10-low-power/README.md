# ch10 · 低功耗支持 —— 章节导航

> 书第 10 章 · 对应实验：后续追加（骨架未建）
> 章导航：本篇

## 本章讲什么

**空闲任务反正都在跑，不如让它干点正事：把 MCU 睡下去。**
本章讲 tickless idle——空闲任务算出"下一个定时事件还有 N 个 tick"，
就把 SysTick 停掉、MCU 进低功耗模式睡 N tick，省下周期性唤醒的电量。

## 只看这一页（速览）

**主线一句话**：空闲时间怎么变电？10.1 对比"钩子里 WFI"的碎觉和 tickless 的一次睡透，10.2 拆 tickless 的三步流程（补 tick 是头号坑），10.3 落到 F103 硬件选睡眠档位和唤醒源。

| 小节 | 一句话结论 |
|---|---|
| 10.1 空闲钩子与 tickless | 空闲钩子 + WFI 改动最小但被 1ms 心跳切成碎觉；tickless 停掉周期 tick、把唤醒源编程到 N tick 后一次睡透。 |
| 10.2 tickless 的三步 | 算 N（太小直接放弃）→ 停 tick 睡（睡前复查空闲）→ 醒后 vTaskStepTick 按**实际**睡眠时长补 tick，不补则全系统时间变慢。 |
| 10.3 F103 睡眠档位与唤醒源 | Sleep 配 SysTick 拉长、Stop 配 RTC 闹钟且醒后先重建时钟再补 tick、Standby 不配对 tickless；µs 级精度、密集 ISR、调试期都别开。 |

**本章最容易踩的坑**：

- 醒来忘记调 `vTaskStepTick` 补 tick——所有延时、超时、定时器集体"时间变慢"（10.2）。
- 提前唤醒时按预期值而不是实际睡眠时长补 tick（10.2）。
- Stop 档醒来后没重建 HSE/PLL 回 72MHz 就补 tick、跑业务（10.3）。
- 调试时没置 DBGMCU 的 DBG_* 位，芯片一睡 SWD 就断连（10.3）。

## API 速查卡

| API / 命令 | 一句话作用 | 易错点 |
|---|---|---|
| `__WFI()` | CPU 睡到下一个中断 | 放空闲钩子里改动最小，但被 tick 切成碎觉 |
| `configUSE_IDLE_HOOK` | 开启空闲钩子 | 置 1 后必须自己实现 `vApplicationIdleHook`，且钩子不能阻塞 |
| `configUSE_TICKLESS_IDLE` | tickless 总开关 | 开了之后睡眠决策权交给 port 层宏 |
| `portSUPPRESS_TICKS_AND_SLEEP(x)` | 算睡→停 tick→睡→补 tick 全流程 | 官方弱符号实现可覆写；预计睡眠太短内部直接放弃 |
| `eTaskConfirmSleepModeStatus()` | 睡前确认真能睡 | 有就绪任务或调度器挂起时不放行 |
| `vTaskStepTick(T)` | 醒后一次性补 T 个 tick | 提前唤醒按**实际**时长补；漏补全系统时间变慢 |
| `DBGMCU->CR` 的 `DBG_SLEEP/STOP/STANDBY` | 睡眠中保持调试连接 | 省电打折，量产固件必须关 |

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [10.1 空闲钩子与 tickless](10.1-空闲钩子与tickless.md) | 钩子 WFI 的天花板、tickless 思路与开启条件 | ✅ |
| [10.2 tickless 的三步](10.2-tickless的三步.md) | 算睡眠 → 停 tick 睡 → vTaskStepTick 补 tick | ✅ |
| [10.3 F103 睡眠档位与唤醒源](10.3-F103睡眠档位与唤醒源.md) | Sleep/Stop/Standby 配对、谁不该开 tickless | ✅ |

## 读完本章你应该能回答

- 为什么"每个 tick 醒来一次"对电池设备是灾难？
- tickless 醒来后为什么要"补 tick"？不补会怎样？
- F103 三档睡眠各关了什么、能被什么唤醒？
- 调试器接着的时候睡眠为什么会"看起来不正常"？（DBGMCU 位）

## 前置 / 后续

- **前置**：[ch03.5 空闲任务](../03-task-management/3.5-空闲任务与钩子.md)
  + [01-stm32/book-notes ch19 SysTick](../../../01-stm32/book-notes/19-systick-and-timer/README.md)
- **后续**：电池场景才需要；HFT/学习主线优先级低，最后补

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节无实测数据、无对应实验 | 学习主线不涉低功耗；列为最末优先级，届时补"开/关 tickless 的电流对比"实测 |
