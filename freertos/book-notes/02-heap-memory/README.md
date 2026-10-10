# ch02 · 堆内存管理 —— 章节导航

> 书第 2 章 · 对应实验：贯穿（[`freertos/01-hello-task`](../../01-hello-task/README.md) 的 heap 选型 ⬜ 未做）
> 章导航：本篇

## 本章讲什么

**FreeRTOS 不强迫你用 C 库的 malloc——它自带五个微型分配器（heap_1 ~ heap_5），
本章回答两个问题：为什么嵌入式里 malloc 是危险品，以及五个 heap 里该选哪个。**

内核自己也要分配内存（任务 TCB、任务栈、队列、信号量），
这些分配走的就是你选的那个 heap_x.c。选型错误 = 跑着跑着 `xTaskCreate` 静默返回失败。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 2.01 | 为什么嵌入式里 malloc 是危险品 | [2.01-为什么嵌入式里malloc是危险品](2.01-为什么嵌入式里malloc是危险品.md) |
| 2.02 | heap_1 ~ heap_5 选型表 | [2.02-heap五个分配器选型](2.02-heap五个分配器选型.md) |
| 2.03 | 本仓选型 heap_4 与 configTOTAL_HEAP_SIZE 怎么定 | [2.03-本仓选型heap_4](2.03-本仓选型heap_4.md) |

## 读完本章你应该能回答

- malloc 在嵌入式里的四个毛病分别是什么？
- heap_2 和 heap_4 都会碎，区别在哪？
- heap_5 比 heap_4 多的那一个能力是什么？（F103 用不上，F407 的 CCM 呢？）
- 任务栈是从哪里来的？删任务后谁负责还？
- `xTaskCreate` 失败时怎么暴露，而不是让系统带病运行？

## 前置 / 后续

- **前置**：[stm32/book-notes ch13 动态内存](../../../stm32/book-notes/13-dynamic-memory/README.md)
  （裸机里 malloc 从哪来、_sbrk 与链接脚本的关系）
- **后续**：[ch03 任务管理](../03-task-management/README.md)——`xTaskCreate` 是第一个
  真正消耗 heap 的 API

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测数据（堆水位、分配失败演示） | 实验未做；`xPortGetFreeHeapSize()` 读数待 01 落地后补 |
