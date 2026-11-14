# ch07 · BLE —— 章节导航

> 书第 7 章 · 对应实验：选读（F103 无 BLE 外设）
> 章导航：本篇

## 本章讲什么

**Zephyr 的 BLE 协议栈（host + controller 架构）与 GATT 应用写法。**
这是书里篇幅很大的一章，但**对本仓库是选读**：
NUCLEO-F103RB 没有 BLE 射频，Blue Pill 也没有；
将来若加 Nordic 板（nRF52 系列原生 Zephyr），这章转正课。

## 只看这一页（速览）

**主线一句话**：这章解决"BLE 在 Zephyr 里怎么跑起来"——先把协议栈拆成应用/host/controller 三层、搞清谁管什么（7.1），再看连上之后数据怎么用 GATT 树组织（7.2），最后算清广播、连接与吞吐这笔账（7.3），三篇是"架构 → 数据模型 → 速度"的递进线。

| 小节 | 一句话结论 |
|---|---|
| 7.1 BLE 栈架构 | BLE 栈拆成应用/host/controller 三层，HCI 是铰链：其上纯软件可移植、其下贴硬件厂商实现，Zephyr 连 controller 都是开源的 |
| 7.2 GATT 服务与特征 | "服务→特征→描述符"树用 BT_GATT_SERVICE_DEFINE 宏族在编译期固化成 const 属性表，没有运行时注册 |
| 7.3 广播、连接与 MTU | 吞吐由 MTU、connection interval、PHY 三个旋钮决定；MTU 属协议层、DLE 属链路层，两个都大才有大吞吐 |

**本章最容易踩的坑**：

- 协议栈回调里 k_sleep 或干重活，整个协议栈被你憋死——要用 k_work_submit 推出去（7.1）
- RX 线程栈给太小，症状是莫名其妙的栈溢出 fatal（7.1）
- CHRC 属性位和 PERM 权限是两回事，只给其中一个，手机读写照样被拒（7.2）
- 手机没写 CCC 描述符登记订阅，你 notify 一百次它也收不到（7.2）
- 只加大 MTU 不调 DLE：车斗加大了车厢没加大，货照样装不下（7.3）

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 7.1 | BLE 栈架构：controller / host / 应用三层 | [7.1-BLE栈架构](7.1-BLE栈架构.md) |
| 7.2 | GATT 服务与特征：用一组宏声明一棵树 | [7.2-GATT服务与特征](7.2-GATT服务与特征.md) |
| 7.3 | 广播、连接与 MTU：BLE 吞吐从哪来 | [7.3-广播连接与MTU](7.3-广播连接与MTU.md) |

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
| 笔记已写但无实验 | F103 无 BLE 外设；nRF52 板加入硬件清单后补实验与实测 |
