# freertos —— FreeRTOS 实验区

> 定位：MCU 轨的**第一遍 RTOS**——不搞框架，只把「任务/调度/队列/信号量/互斥量」
> 这五件事在真机上看明白。第二遍（工程化）在 [zephyr/](../zephyr/README.md) 用 Zephyr 重做。
> 对应笔记：[补充 ch20 走向 FreeRTOS](../book-notes/20-towards-freertos/README.md)（先行讲解篇，
> 机制原理都在那里，本目录负责出实测数据）

## 前置

- stm32/01–06 全部真机跑通：会点灯（03）、会串口（04）、会中断（05）、会定时器（06）
- 读完 ch20 三篇再动手——PendSV/SysTick/双栈不懂，FreeRTOS 就是黑盒

## 实验规划（与 [zephyr/](../zephyr/README.md) 一一对照，学两遍 = 记两遍）

| # | 实验 | 主题 | 对应笔记 | 对应 zephyr | 状态 |
|---|---|---|---|---|---|
| 01 | [hello-task](01-hello-task/README.md) | 两任务交替 + 调度器观测 | ch20.1 | zephyr/01-hello | ⬜ 骨架已建 |
| 02 | [queue](02-queue/README.md) | 中断→队列→任务（下半部的 RTOS 版） | ch20.2 + 书 10.5 | zephyr/02-threads-msgq | ⬜ 骨架已建 |
| 03 | [semaphore](03-semaphore/README.md) | 二值信号量按键去抖 | ch20.2 + 书 ch05 | zephyr/03-semaphore | ⬜ 骨架已建 |
| 04 | [mutex-priority](04-mutex-priority/README.md) | 优先级反转 vs 优先级继承 | ch20.3 | zephyr/04-mutex-priority | ⬜ 骨架已建 |

## 源码与移植（F103 = Cortex-M3）

- 官方 **FreeRTOS-Kernel**（**MIT** 许可，静态链接无义务）：git clone 或下 release 包，
  建议挂 `third_party/` 子模块（与 libopencm3 同规矩，钉死 commit）
- 需要的文件只有：`tasks.c queue.c list.c` + `portable/GCC/ARM_CM3/port.c`
  + `portable/MemMang/heap_4.c`——**port 层一行不改**
- 自己要写的：`FreeRTOSConfig.h`（时钟/tick/heap/钩子是全部配置）+ 应用 `main.c`
- 向量表里 `SVC/PendSV/SysTick` 三个 handler 指到 port 层函数（01-hello-task 的第一个坑）

## RAM 预算纪律（20K 是硬约束）

- `configTOTAL_HEAP_SIZE` 先 8K；每个任务栈单独算（01 的验收项之一就是出 RAM 账）
- `configCHECK_FOR_STACK_OVERFLOW=2` 和 `configASSERT` 从第一个实验就开——
  裸机没有守卫页，RTOS 的栈检查是你唯一的网
- 每加一个实验更新一次预算表（写进对应实验 README）

## 纪律（沿用全仓惯例）

- 每个实验真机跑通再写笔记，实测输出（串口文本、gdb 截图、RAM/Flash 账）贴进对应 README
- 重点记「手写裸机版（书 ch10/19）怎么做 / FreeRTOS 怎么做 / 框架替我包了什么、代价多少」
- ISR 里只调 `*FromISR` API；`pxHigherPriorityTaskWoken` 的用法每个实验都要检查
