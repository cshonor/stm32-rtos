# ch12 · 故障排查 —— 章节导航

> 书第 12 章 · 对应实验：[`02-freertos/01-hello-task`](../../01-hello-task/README.md)（⬜ 未做；卡住时先翻本章再翻调试器）
> 章导航：本篇

## 本章讲什么

**官方总结的"FreeRTOS 应用死机原因排行榜"。**
多年技术支持统计，排前面的永远是那几类：栈不够、中断优先级配错、
在 ISR 里调了非 FromISR API、临界区里调了会阻塞的 API。
本章是"对照自查表"，不是教程。

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [12.1 症状→病因对照表](12.1-症状病因对照表.md) | 死在启动前/后、跑会儿死、printf 三重罪、排查顺序总纲 | ✅ |
| [12.2 中断优先级三大错](12.2-中断优先级三大错.md) | syscall 红线、NVIC 分组、FromISR 混用 | ✅ |
| [12.3 栈问题与 HardFault 定位](12.3-栈问题与HardFault定位.md) | 栈三死相、MSP/PSP 判别、stacked PC 解剖 | ✅ |

## 读完本章你应该能回答

- `vTaskStartScheduler()` 一调就 HardFault，最先查哪三样？
- "任务跑起来了但永远不切"可能是哪个配置错了？
- 为什么优先级分组（NVIC_PRIORITYGROUP_4）配错会让 syscall 红线失效？
- printf 在 RTOS 里为什么本身就是事故高发区？

## 前置 / 后续

- **前置**：[ch06 中断管理](../06-interrupt-management/README.md)
  + [ch11 开发者支持](../11-developer-support/README.md)（检测工具全在那章）
  + [19.6 时间相关的三个经典 Bug](../../../01-stm32/book-notes/19-systick-and-timer/19.6-时间相关的三个经典Bug.md)
  + [20.1 任务与调度的硬件落点](../../../01-stm32/book-notes/20-towards-freertos/20.1-任务与调度的硬件落点.md)
- **后续**：实验卡住时**先翻这章再翻调试器**

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节无实测数据 | 本章骨架按官方书语义写成；等实验真踩到坑，把真实死相/寄存器截图补进对应小节 |
| HardFault 汇编入口未上板验证 | naked 函数写法待实验 01 落地时实测，必要时按 port 调整 |
