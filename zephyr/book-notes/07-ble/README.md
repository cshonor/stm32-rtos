# ch07 · BLE —— 章节导航

> 书第 7 章 · 对应实验：选读（F103 无 BLE 外设）
> 章导航：本篇

## 本章讲什么

**Zephyr 的 BLE 协议栈（host + controller 架构）与 GATT 应用写法。**
这是书里篇幅很大的一章，但**对本仓库是选读**：
NUCLEO-F103RB 没有 BLE 射频，Blue Pill 也没有；
将来若加 Nordic 板（nRF52 系列原生 Zephyr），这章转正课。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 7.1 | BLE 栈架构：controller / host / 应用三层 | ⬜ |
| 7.2 | GATT 服务与特征：用宏声明一个服务 | ⬜ |
| 7.3 | 广播、连接、MTU 与吞吐的关系 | ⬜ |

## 读完本章你应该能回答

- Zephyr BLE 的 host 和 controller 分别跑在哪？（单芯片 vs 双芯片方案）
- GATT 的 service/characteristic/descriptor 三层各是什么？
- 为什么 Nordic 全家都押 Zephyr？（nRF Connect SDK = Zephyr 下游）

## 前置 / 后续

- **前置**：无硬前置；[ch04](../04-multithreading/README.md) 的线程模型是理解协议栈线程划分的基础
- **后续**：等 nRF52 板加入硬件清单再启动

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 全章未写 | 无硬件，纯纸上谈 BLE 没有学习价值；硬件到位再启动 |
