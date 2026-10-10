# ch01 · 导论 —— 章节导航

> 书第 1 章 · 对应实验：贯穿
> 章导航：本篇

## 本章讲什么

**Zephyr 是什么、从哪来、为什么和 FreeRTOS 不是同一类东西。**
FreeRTOS 是"一个内核"（调度 + IPC，其他自己搭）；
Zephyr 是"一个平台"——内核 + 驱动模型 + 协议栈 + 文件系统 + 构建系统，
更像 MCU 上的"小 Linux"。这个定位差异决定了两条轨的学习方法不同：
FreeRTOS 学**机制**，Zephyr 学**机制 + 框架的使用方式**。

血统事实：Zephyr 源自 Wind River 的 Rocket OS，2016 年交给 Linux 基金会托管
（Apache 2.0），Nordic / NXP / Intel 等是主力贡献者。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 1.1 | Zephyr 家谱：Wind River → Linux 基金会，许可证与生态 | ⬜ |
| 1.2 | "内核" vs "平台"：Zephyr 与 FreeRTOS 的定位对照 | ⬜ |
| 1.3 | 支持的板卡与架构：为什么"换板不改应用"是设计目标 | ⬜ |

## 读完本章你应该能回答

- Zephyr 的许可证是什么？和 libopencm3 的 LGPL 比，对产品意味着什么？
- "平台"比"内核"多出来的四层分别是什么？
- 为什么 Nordic 的 nRF 系列全家用 Zephyr（nRF Connect SDK）？

## 前置 / 后续

- **前置**：无（全书的入口）
- **后续**：[ch02 RTOS 基础复习](../02-rtos-fundamentals/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写 | 导论类内容随读随补，优先级最低 |
