# ch11 · 开发者支持 —— 章节导航

> 书第 11 章 · 对应实验：[`02-freertos/labs/01-hello-task`](../labs/01-hello-task/README.md)（⬜ 未做；落地当天就配 configASSERT + 栈检测方法二）
> 章导航：本篇

## 本章讲什么

**FreeRTOS 留给开发者的"自检与观测"工具箱：configASSERT、栈溢出检测的
两种方法、运行时统计（每个任务吃了多少 CPU）、trace 钩子宏。**
这一章是"调试期保命手册"——不出事时用不上，出事了全是它。

## 只看这一页（速览）

**主线一句话**：怎么把 bug 照出来？11.1 用 configASSERT 让错误死在现场，11.2 用两档检测抓栈溢出，11.3 用四个 API 出"体检报告单"，11.4 用 trace 钩子宏连续录像抓时序病——从点、到面、到时间线逐层升级。

| 小节 | 一句话结论 |
|---|---|
| 11.1 configASSERT 总开关 | configASSERT 默认是空宏，配上"关中断 + 死循环"让错误参数死在 API 入口；malloc 失败钩子是 heap 耗尽的强制停车闸。 |
| 11.2 栈溢出检测两档 | 方法一查切换瞬间的 SP 现状，方法二查 0xA5 填充痕迹（更严，调试期标配）；溢出钩子里只停车；水位 API 用来科学定栈深。 |
| 11.3 任务与堆水位观测 | vTaskList 一张表看全部任务状态与栈水位；运行时统计的时基必须 ≥10 倍 tick（F103 用 TIM2 自由跑读 CNT）；定 heap 大小看历史最小剩余。 |
| 11.4 trace 钩子宏家族 | trace 宏是内核预留的空插槽，定义即埋点且不改内核源码；三军规：不阻塞、要极快、警惕观察者效应；Tracealyzer 专抓时序病。 |

**本章最容易踩的坑**：

- 以为 FreeRTOS 开箱自带参数检查——configASSERT 不配就是空宏，内核从不体检（11.1）。
- 在栈溢出钩子里 printf 或调内核 API——栈都爆了，环境已不可信，只能停车（11.2）。
- 运行时统计的时基和 tick 同速（1ms），任务切换耗时全测成 0（11.3）。
- trace 钩子里放 printf 拖垮调度；在高频路径里调 vTaskList（它会挂起调度器遍历所有 TCB）（11.4/11.3）。

## API 速查卡

| API / 命令 | 一句话作用 | 易错点 |
|---|---|---|
| `configASSERT(x)` | 内核参数/状态校验总开关 | 默认空宏，不配 = 内核从不体检 |
| `taskDISABLE_INTERRUPTS()` | 断言/钩子里的停车动作 | 关中断后 printf 可能出不来，现场靠调试器看 |
| `vApplicationMallocFailedHook` | heap 耗尽强制停车 | 需 `configUSE_MALLOC_FAILED_HOOK` 置 1 |
| `configCHECK_FOR_STACK_OVERFLOW` | 栈溢出检测档位 | 调试期一律 2（查 0xA5 痕迹），1 只看切换瞬间 SP |
| `vApplicationStackOverflowHook` | 溢出钩子，参数带任务名 | 钩子里只许停车，禁 printf/内核 API |
| `uxTaskGetStackHighWaterMark(NULL)` | 本任务历史最小剩余栈（单位：字） | "水位"是**剩多少**不是用多少，越小越危险 |
| `vTaskList(buf)` | 全部任务状态+栈水位文本表 | 挂起调度器遍历 TCB，别放高频路径；buf 按任务数给够 |
| `vTaskGetRunTimeStats(buf)` | 各任务 CPU 占用表 | 时基必须 ≥10× tick（F103 用 TIM 自由跑读 CNT） |
| `xPortGetFreeHeapSize()` | 此刻 heap 剩余 | 只含 `pvPortMalloc`，不含 C 库 malloc 和 MSP 栈 |
| `xPortGetMinimumEverFreeHeapSize()` | heap 历史最小剩余 | 定 `configTOTAL_HEAP_SIZE` 看它并留 30–50% 余量 |
| `traceTASK_SWITCHED_IN()` | 任务切入埋点 | 每次切换都跑，里面禁阻塞禁 printf |

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [11.1 configASSERT 总开关](11.1-configASSERT总开关.md) | 内核参数校验、标准写法、malloc 失败钩子 | ✅ |
| [11.2 栈溢出检测两档](11.2-栈溢出检测两档.md) | 方法一（查 SP）/方法二（查 0xA5 填充）、溢出钩子、栈水位 | ✅ |
| [11.3 任务与堆水位观测](11.3-任务与堆水位观测.md) | vTaskList / 运行时统计 + 高速时基 / 堆水位两 API | ✅ |
| [11.4 trace 钩子宏家族](11.4-trace钩子宏家族.md) | 内核埋点插槽、Tracealyzer 概念、钩子三军规 | ✅ |

## 读完本章你应该能回答

- configASSERT 和 C 库 assert 的区别？为什么嵌入式里更敢用？
- 栈检测方法一（查栈指针）和方法二（查填充模式）谁更严？
- 运行时统计需要一个比 tick 快 10 倍以上的时基，为什么？F103 上用什么当这个时基？
- `uxTaskGetStackHighWaterMark` 的"高水位"是剩多还是剩少？

## 前置 / 后续

- **前置**：[ch03 任务管理](../03-task-management/README.md)
  + [ch02 堆内存](../02-heap-memory/README.md)
- **后续**：[ch12 故障排查](../12-troubleshooting/README.md)（本章工具对应哪种死相）
  → 实验 [`02-freertos/labs/01-hello-task`](../labs/01-hello-task/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节无实测数据 | 实验 01 未做；届时补真实的断言触发现场、栈水位读数、运行时统计表 |
| Tracealyzer 只有概念 | recorder 库接入和 PC 端回放要等实验落地后验证 |
