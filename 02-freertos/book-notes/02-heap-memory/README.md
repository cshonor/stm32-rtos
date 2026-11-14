# ch02 · 堆内存管理 —— 章节导航

> 书第 2 章 · 对应实验：贯穿（[`02-freertos/01-hello-task`](../../01-hello-task/README.md) 的 heap 选型 ⬜ 未做）
> 章导航：本篇

## 本章讲什么

**FreeRTOS 不强迫你用 C 库的 malloc——它自带五个微型分配器（heap_1 ~ heap_5），
本章回答两个问题：为什么嵌入式里 malloc 是危险品，以及五个 heap 里该选哪个。**

内核自己也要分配内存（任务 TCB、任务栈、队列、信号量），
这些分配走的就是你选的那个 heap_x.c。选型错误 = 跑着跑着 `xTaskCreate` 静默返回失败。

## 只看这一页（速览）

**主线一句话**：内核分配不走 C 库 malloc 而走自带的 heap_x——2.1 先立 malloc 的
四宗罪和 `pvPortMalloc` 的拆解，2.2 把 heap_1~5 摆成一张选型表，2.3 钉死本仓选
heap_4 并用"先估算、再量水位、后收紧"的方法定 `configTOTAL_HEAP_SIZE`。

| 小节 | 一句话结论 |
|---|---|
| 2.1 为什么嵌入式里 malloc 是危险品 | malloc 耗时不定、会碎、重入靠锁、失败难察；内核全走 `pvPortMalloc` + 定长 `ucHeap`，堆撞栈在结构上消失 |
| 2.2 heap 五个分配器选型 | 五个 heap 是五种权衡不是版本递进：建完不删用 heap_1、动态创建删除用 heap_4、多段 RAM 用 heap_5 |
| 2.3 本仓选型 heap_4 | 选 heap_4；堆大小先按清单估算取 8K 起步，再用水位 API 收紧，并配 malloc failed hook 当场抓失败 |

**本章最容易踩的坑**

- heap_1~5 一起编进工程 = 同名函数链接冲突，只能五选一，换要改 Makefile 重编（2.1）
- heap_4 的相邻合并消灭不了碎片；创建/删除的对象大小不归一化，照样"总量够、单块不够"（2.2）
- `configTOTAL_HEAP_SIZE` 先紧后爆最难受，标准流程是先宽后紧、用水位读数收紧（2.3）
- MSP 中断栈不走 heap，预算里漏留会悄悄踩 .bss/ucHeap，而不是立刻 HardFault（2.3）
- 不配 `vApplicationMallocFailedHook`，`xTaskCreate` 失败就静默带病运行（2.3）

## API 速查卡

| API / 命令 | 一句话作用 | 易错点 |
|---|---|---|
| `pvPortMalloc( n )` | 从 `ucHeap` 静态数组分配 n 字节 | ISR 里不能调；返回 NULL 必须检查 |
| `vPortFree( p )` | 归还 `pvPortMalloc` 拿的内存 | heap_1 下是空操作；释放后指针置 NULL 防悬空 |
| `vPortDefineHeapRegions()` | heap_5 专用：登记多段不连续 RAM | heap_1~4 没有此函数；要在任何分配前调用 |
| `configTOTAL_HEAP_SIZE` | 定死 `ucHeap` 数组大小 | 先宽后紧；给小了 `xTaskCreate` 静默失败 |
| `vApplicationMallocFailedHook()` | 分配失败时内核回调 | 函数体要自己写，必须当场停车，空钩子等于没配 |
| `configCHECK_FOR_STACK_OVERFLOW` | 栈溢出检测开关（1 或 2） | 方法 2 更可靠；有性能开销，调通后再开 |
| `xPortGetFreeHeapSize()` | 当前堆剩余字节数 | 只是当前值，看不出峰值 |
| `xPortGetMinimumEverFreeHeapSize()` | 历史最低堆剩余（峰值水位） | 收紧堆大小的依据；要跑过最忙场景再读 |
| `uxTaskGetStackHighWaterMark( NULL )` | 本任务栈历史最深用量 | 单位是**字**不是字节 |
| `taskDISABLE_INTERRUPTS()` | 关全部中断 | 只用在 hook/致命错误处理里，别当临界区常规手段 |

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 2.1 | 为什么嵌入式里 malloc 是危险品 | [2.1-为什么嵌入式里malloc是危险品](2.1-为什么嵌入式里malloc是危险品.md) |
| 2.2 | heap_1 ~ heap_5 选型表 | [2.2-heap五个分配器选型](2.2-heap五个分配器选型.md) |
| 2.3 | 本仓选型 heap_4 与 configTOTAL_HEAP_SIZE 怎么定 | [2.3-本仓选型heap_4](2.3-本仓选型heap_4.md) |

## 读完本章你应该能回答

- malloc 在嵌入式里的四个毛病分别是什么？
- heap_2 和 heap_4 都会碎，区别在哪？
- heap_5 比 heap_4 多的那一个能力是什么？（F103 用不上，F407 的 CCM 呢？）
- 任务栈是从哪里来的？删任务后谁负责还？
- `xTaskCreate` 失败时怎么暴露，而不是让系统带病运行？

## 前置 / 后续

- **前置**：[01-stm32/book-notes ch13 动态内存](../../../01-stm32/book-notes/13-dynamic-memory/README.md)
  （裸机里 malloc 从哪来、_sbrk 与链接脚本的关系）
- **后续**：[ch03 任务管理](../03-task-management/README.md)——`xTaskCreate` 是第一个
  真正消耗 heap 的 API

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测数据（堆水位、分配失败演示） | 实验未做；`xPortGetFreeHeapSize()` 读数待 01 落地后补 |
