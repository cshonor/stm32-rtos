# ch12 · 故障排查 —— 章节导航

> 书第 12 章 · 对应实验：[`02-freertos/01-hello-task`](../../01-hello-task/README.md)（⬜ 未做；卡住时先翻本章再翻调试器）
> 章导航：本篇

## 本章讲什么

**官方总结的"FreeRTOS 应用死机原因排行榜"。**
多年技术支持统计，排前面的永远是那几类：栈不够、中断优先级配错、
在 ISR 里调了非 FromISR API、临界区里调了会阻塞的 API。
本章是"对照自查表"，不是教程。

## 只看这一页（速览）

**主线一句话**：死机了按什么顺序查？12.1 先按"死在哪一刻"分诊（三大经典病因：栈溢出、heap 耗尽、优先级方向记反），12.2 专攻常年霸榜的中断优先级红线三大错，12.3 给 HardFault 的标准解剖流程。

| 小节 | 一句话结论 |
|---|---|
| 12.1 症状→病因对照表 | 先分死相（启动即死 / 不切任务 / 跑会儿死 / printf 诱发）再对病因；printf 有互踩、爆栈、扰动时序三重罪，日志必须单任务化。 |
| 12.2 中断优先级三大错 | 红线规则：调 FromISR API 的中断优先级数值必须 ≥ configMAX_SYSCALL_INTERRUPT_PRIORITY；Cortex-M 数字小 = 级别高，分组必须 GROUP_4 且只设一次。 |
| 12.3 栈问题与 HardFault 定位 | 栈溢出几乎从不死在溢出当下；HardFault 定位先用 LR bit2 分 MSP/PSP，再读 pulStack[6] 的 stacked PC 配 addr2line 定位到行。 |

**本章最容易踩的坑**：

- 把中断优先级也当成"数字大 = 级别高"——Cortex-M 方向正好相反，这是头号摔法（12.2）。
- 优先级分组被 HAL_Init 等设成非 GROUP_4，红线静默失效而且"能跑很久才炸"（12.2）。
- 在 ISR 里调不带 FromISR 后缀的 API（12.2）。
- 拿 printf 当调试主力：互踩、吃栈、还会制造一加调试就消失的 Heisenbug（12.1）。
- 创建 API 不查返回值、不配 malloc 钩子，heap 慢性耗尽无声发作几天后才崩（12.1）。

## API 速查卡

| API / 命令 | 一句话作用 | 易错点 |
|---|---|---|
| `xTaskCreate` 等创建 API | 创建任务/队列 | 返回值必须查，失败时无声无息 |
| `xTaskGetTickCount()` | 读 tick 计数 | 时间比较要写回绕安全差值（49.7 天坑） |
| `configUSE_TIME_SLICING` | 同优先级时间片轮转 | 解"高优先级空转"，但救不了永不阻塞的任务 |
| `configMAX_SYSCALL_INTERRUPT_PRIORITY` | FromISR API 红线 | 数值 ≥ 它才能调 API；Cortex-M 数字小=级别高，方向别记反 |
| `NVIC_SetPriority(irq, n)` | 设中断优先级 | n 是库语义值 0–15，不是移位后的寄存器值（差 16 倍） |
| `NVIC_PRIORITYGROUP_4` | 优先级位全归抢占 | 全系统只设一次，配错红线静默失效 |
| `xQueueSendFromISR()` 等 | ISR 里的内核 API | ISR 里只认 FromISR 后缀 |
| `portYIELD_FROM_ISR(x)` | ISR 末尾按标志触发切换 | 忘调则被唤醒的高优先级任务晚一个 tick |
| `HardFault_Handler` | 故障总入口 | 默认 `b .` 丢现场；要 naked 汇编入口按 LR bit2 取对栈指针 |
| `pulStack[6]`（stacked PC） | 肇事指令地址 | 可能是受害者不是凶手；非精确错时前后看几条 |
| `SCB->CFSR` / `SCB->BFAR` | 故障类型 / 肇事内存地址 | BFAR 仅"精确"总线错时有效 |
| `arm-none-eabi-addr2line -e x.elf <pc>` | 地址翻译成文件行号 | elf 要带 `-g` 调试符号 |

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
