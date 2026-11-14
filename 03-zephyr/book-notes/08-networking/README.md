# ch08 · Ethernet / WiFi / TCP-IP —— 章节导航

> 书第 8 章 · 对应实验：后续追加（骨架未建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的网络子系统：net_context/socket API、网络接口抽象、
以及协议栈线程模型。**Zephyr 自带完整 TCP/IP 栈（不用外挂 lwIP），
socket API 与 POSIX 对齐——从 Linux 网络编程（`04-cpp/M2` 那条线）过来
几乎是零成本。

## 只看这一页（速览）

**主线一句话**：这章解决"MCU 怎么连上网"——先立 Zephyr 自带网络栈的分层架构与线程模型（8.1），再看应用层唯一要碰的 socket API 与 POSIX 差多少（8.2），最后解决 F103 没网卡的物理链路选型（8.3），三篇是"架构 → API → 路径"的递进线。

| 小节 | 一句话结论 |
|---|---|
| 8.1 网络栈架构 | Zephyr 自带 native TCP/IP 栈：驱动 → net_if → L2 → IP → socket 分层，RX/TX 各是内核线程，net_buf 配额是 RAM 与稳定性的对价 |
| 8.2 socket API 与 POSIX | zsock_* 与 BSD socket 逐项对齐，差异不在 API 在 RAM 资源观；TLS 用 SOL_TLS setsockopt，F103 上交给模组 |
| 8.3 F103 上网路径 | 四条路径按"TCP/IP 栈长在哪"分类：纯转发（ENC28J60）、硬件 offload（W5500）、AT offload（ESP-AT/4G）、仿真（QEMU）；F103 现实选型 W5500 或 ESP-AT |

**本章最容易踩的坑**：

- net_buf 缓冲配额耗尽，症状是丢包、TCP 卡死、大 MTU 流量直接断流（8.1）
- RX 线程优先级和 socket 所在线程优先级直接决定收包路径的抖动分布（8.1）
- 照搬 PC 思维开几十个 socket：默认连接数只有个位数到十几个（8.2）
- 把 zsock_recv 返回 0 当错误——那是对端正常关闭，不是故障（8.2）
- AT offload 路径的 fd 不是本机真 socket，错误码/并发/DNS 受模组固件约束，移植代码要在真模组上回归（8.3）

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 8.1 | 网络栈架构：iface → L2 → IP → socket 层 | [8.1-网络栈架构](8.1-网络栈架构.md) |
| 8.2 | socket API 与 POSIX 的对应与缺口 | [8.2-socket-API与POSIX](8.2-socket-API与POSIX.md) |
| 8.3 | F103 怎么上网：SPI 网卡 / Wi-Fi 模组 / 4G 模组 / QEMU | [8.3-F103上网路径](8.3-F103上网路径.md) |

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
| 笔记已写但无实验 | F103 无板载网络；QEMU 路径或 W5500/ESP-AT 硬件到位后补实测 |
| 书 API 与新版有差 | 已按官方文档校正（net_context 已移除，一律 zsock_*；ESP-AT 驱动体系化） |
