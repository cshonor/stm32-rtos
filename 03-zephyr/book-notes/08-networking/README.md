# ch08 · Ethernet / WiFi / TCP-IP —— 章节导航

> 书第 8 章 · 对应实验：后续追加（骨架未建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的网络子系统：net_context/socket API、网络接口抽象、
以及协议栈线程模型。**Zephyr 自带完整 TCP/IP 栈（不用外挂 lwIP），
socket API 与 POSIX 对齐——从 Linux 网络编程（`04-cpp/M2` 那条线）过来
几乎是零成本。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 8.01 | 网络栈架构：iface → L2 → IP → socket 层 | ⬜ |
| 8.02 | socket API 与 POSIX 的对应与缺口 | ⬜ |
| 8.03 | F103 怎么上网：SPI 网卡（ENC28J60/W5500）与 QEMU 仿真路径 | ⬜ |

## 读完本章你应该能回答

- Zephyr 的 socket 和 lwIP 的 socket 在使用上差多少？
- 无 MAC 外设的 F103 有哪些联网路径？各自的代价？
- 网络收发各跑在什么线程上下文？（对照 BLE 章的线程划分）

## 前置 / 后续

- **前置**：[ch04](../04-multithreading/README.md) + `04-cpp/M2` 网络编程的 socket 经验
- **后续**：HFT 关联——网络路径的线程/优先级配置直接影响时延分布

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节未写、无实验 | F103 无板载网络；SPI 网卡或 QEMU 路径待定后再写 |
