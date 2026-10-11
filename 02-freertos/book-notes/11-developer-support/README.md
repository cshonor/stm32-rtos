# ch11 · 开发者支持 —— 章节导航

> 书第 11 章 · 对应实验：[`02-freertos/01-hello-task`](../../01-hello-task/README.md)（⬜ 未做；落地当天就配 configASSERT + 栈检测方法二）
> 章导航：本篇

## 本章讲什么

**FreeRTOS 留给开发者的"自检与观测"工具箱：configASSERT、栈溢出检测的
两种方法、运行时统计（每个任务吃了多少 CPU）、trace 钩子宏。**
这一章是"调试期保命手册"——不出事时用不上，出事了全是它。

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
  → 实验 [`02-freertos/01-hello-task`](../../01-hello-task/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节无实测数据 | 实验 01 未做；届时补真实的断言触发现场、栈水位读数、运行时统计表 |
| Tracealyzer 只有概念 | recorder 库接入和 PC 端回放要等实验落地后验证 |
