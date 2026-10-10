# 01-hello-task —— 两个任务 LED 交替（调度器第一课）

> 状态：⬜ 未开始（骨架）。
> 对应笔记：[补充 ch20 走向 FreeRTOS](../../stm32/book-notes/20-towards-freertos/README.md)
> （20.01 任务与调度的硬件落点：SysTick + PendSV + 双栈）
> 前置：stm32/01–06 全部真机跑通（点灯、串口、中断、定时器）
> 对照：zephyr/01-hello（第二遍用 Zephyr 再做一次）

## 目标

- FreeRTOS 最小移植跑起来：两个任务，各以不同周期翻转 LED（PA5）+ 串口打印
- 亲眼看到「调度器」不是概念：`vTaskDelay` 让出 CPU、idle 任务、SysTick 变成 RTOS 的心跳

## 移植要点（F103 = Cortex-M3）

- 源码：FreeRTOS-Kernel（**MIT**），只取 `tasks.c queue.c list.c` + `portable/GCC/ARM_CM3/port.c`
  + `portable/MemMang/heap_4.c`
- 只写两个文件：`FreeRTOSConfig.h` + `main.c`——**不动 port 层**
- `FreeRTOSConfig.h` 关键项：`configCPU_CLOCK_HZ`（先 8 MHz，配 PLL 后改 72M）、
  `configTICK_RATE_HZ = 1000`、`configTOTAL_HEAP_SIZE`（20K RAM 里先给 8K）、
  `configMINIMAL_STACK_SIZE`（先 128 字）
- 启动文件里的 `SVC_Handler / PendSV_Handler / SysTick_Handler` 三个向量
  要指到 port 层实现的函数（vPortSVCHandler / xPortPendSVHandler / xPortSysTickHandler）——
  向量表改名是本实验第一个坑

## 步骤

1. 从 stm32/04-uart-printf 的工程复制 Makefile/链接脚本，加入 kernel 源文件
2. `xTaskCreate` × 2：task_a 500 ms 翻灯，task_b 1 s 打串口计数
3. `vTaskStartScheduler()` —— 这行之后 main 不再返回
4. 串口观察两任务的交错；gdb 停在 `xPortPendSVHandler` 看任务切换现场

## 验收

- 两任务各自周期稳定（串口时间戳对照）
- gdb 里 `pxCurrentTCB` 在 PendSV 前后指向不同任务——实测截图贴进本 README
- RAM 账：heap + 两任务栈 + idle 栈 + 静态 = 多少，距 20K 上限的余量写出来

## 坑点（待记）

- 中断优先级数值越大优先级越低（Cortex-M 反直觉），`configMAX_SYSCALL_INTERRUPT_PRIORITY`
  设错 → 高优先级 ISR 调 API 直接 HardFault
- 栈给小了不会报错，是踩内存——`configCHECK_FOR_STACK_OVERFLOW` 先开起来
