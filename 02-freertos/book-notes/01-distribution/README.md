# ch01 · FreeRTOS 内核分发包 —— 章节导航

> 书第 1 章 · 对应实验：贯穿（移植取材，落点 [`02-freertos/01-hello-task`](../../01-hello-task/README.md) ⬜ 未做）
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

## 只看这一页（速览）

**主线一句话**：官方分发包几百个文件里移植只需要 6 个——1.1 给出最小取材清单
（Source 留下、Demo 别抄），1.2 解释 port 层为什么对 F103 零修改，1.3 把唯一要
自己写的 FreeRTOSConfig.h 逐项过完并标出三颗"编译过但跑死"的雷。

| 小节 | 一句话结论 |
|---|---|
| 1.1 分发包结构与移植取材 | 最小集 = tasks/queue/list 三核心 + 一个 port + 一个 heap + 自写 Config，Demo 只看不抄 |
| 1.2 portable 层是什么 | port 层封装上下文切换、tick/启动、临界区三件事；Cortex-M 内核标准化使同架构同编译器的 port 零修改 |
| 1.3 FreeRTOSConfig 逐项过一遍 | 配置全是编译期 #define；三颗雷（CPU 时钟宏、中断红线宏、堆太小）全是"编译过但跑死"型 |

**本章最容易踩的坑**

- 把整个 Demo 复制进工程再改：Config 按别人的板子/晶振配的，tick 速率全错（1.1）
- `configCPU_CLOCK_HZ` 配错 → SysTick 重装值算错，所有延时偏快/偏慢但能正常跑（1.3）
- 漏掉三行 Handler 映射（SVC/PendSV/SysTick）→ 第一个任务永远启动不了（1.3）
- `configTOTAL_HEAP_SIZE` 给小 → `xTaskCreate` 静默失败，任务没建起来但 main 看不出来（1.3）
- 没有现成 port 就自写：切换错误 = 随机 HardFault，调试成本极高，F103+GCC 有现成 port 永远别自写（1.2）

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [1.1 分发包结构与移植取材](1.1-分发包结构与移植取材.md) | Source vs Demo，移植只取哪 6 个文件 | ✅ |
| [1.2 portable 层是什么](1.2-portable层是什么.md) | 为什么 F103 直接用 ARM_CM3 不用改 | ✅ |
| [1.3 FreeRTOSConfig.h 逐项过一遍](1.3-FreeRTOSConfig逐项过一遍.md) | 本仓 01 实验的配置方向 | ✅ |

## 读完本章你应该能回答

- `tasks.c / queue.c / list.c` 各自负责什么？为什么 `list.c` 这么小却不能省？
- port 层到底封装了哪三件事？（上下文切换汇编、SysTick 配置、临界区）
- `FreeRTOSConfig.h` 里哪三项配错会"编译过但跑死"？
- 为什么不能直接把 Demo 工程整个复制来改？

## 前置 / 后续

- **前置**：[01-stm32/book-notes ch11 链接器](../../../01-stm32/book-notes/11-linker/README.md)
  （内核源码进工程后，向量表/启动文件的关系要看得懂）
- **后续**：[ch02 堆内存管理](../02-heap-memory/README.md)——heap_4.c 就是本章"五选一"的那一格

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测数据 | 实验 01 未做；届时对照真实移植清单与 Config 值补实测 |
| 未核对新版内核目录变化 | 书基于 V10 时代目录，V11 有微调；动手移植时以官方仓为准 |
