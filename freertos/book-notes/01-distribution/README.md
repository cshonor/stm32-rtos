# ch01 · FreeRTOS 内核分发包 —— 章节导航

> 书第 1 章 · 对应实验：贯穿（移植取材，落点 [`freertos/01-hello-task`](../../01-hello-task/README.md) ⬜ 未做）
> 章导航：本篇

## 本章讲什么

**FreeRTOS 官方压缩包里几百个文件，移植一个 F103 工程真正需要的只有 6 个。**
本章把分发包结构拆开，回答"哪些必须抄进工程、哪些是参考、哪些千万别碰"。

```
FreeRTOS/
├── Source/            ← 内核本体（我们要的）
│   ├── tasks.c queue.c list.c      ← 三个核心 .c
│   ├── portable/GCC/ARM_CM3/port.c ← F103 = Cortex-M3，用这个 port
│   ├── portable/MemMang/heap_4.c   ← 五选一（ch02 选型）
│   └── include/                    ← 全部头文件
└── Demo/              ← 几十块板的示例（只看 CORTEX_STM32F103 找感觉，不抄）
```

另有一个必须由**自己写**的文件：`FreeRTOSConfig.h`——时钟频率、tick 速率、
堆大小、钩子开关、裁剪开关全在里面，是 FreeRTOS 的"全部配置"。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 1.01 | 分发包结构：Source vs Demo，移植只取哪 6 个文件 | ⬜ |
| 1.02 | portable 层是什么：为什么 F103 直接用 ARM_CM3 不用改 | ⬜ |
| 1.03 | FreeRTOSConfig.h 逐项过一遍（本仓 01 实验的实际配置） | ⬜ |

## 读完本章你应该能回答

- `tasks.c / queue.c / list.c` 各自负责什么？为什么 `list.c` 这么小却不能省？
- port 层到底封装了哪三件事？（上下文切换汇编、SysTick 配置、临界区）
- `FreeRTOSConfig.h` 里哪三项配错会"编译过但跑死"？
- 为什么不能直接把 Demo 工程整个复制来改？

## 前置 / 后续

- **前置**：[stm32/book-notes ch11 链接器](../../../stm32/book-notes/11-linker/README.md)
  （内核源码进工程后，向量表/启动文件的关系要看得懂）
- **后续**：[ch02 堆内存管理](../02-heap-memory/README.md)——heap_4.c 就是本章"五选一"的那一格

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写 | 随 `freertos/01-hello-task` 实验落地时补（届时有真实的移植清单可贴） |
| 未核对新版内核目录变化 | 书基于 V10 时代目录，V11 有微调；动手移植时以官方仓为准 |
