# ch12 · Wi-Fi 专题 —— 章节导航

> 书第 12 章 · 对应实验：选读（F103 无 Wi-Fi）
> 章导航：本篇

## 本章讲什么

**Zephyr 的 Wi-Fi 支持：扫描/连接管理 API、Wi-Fi 驱动模型、
常见外挂方案（ESP32 作 modem / 原生 Wi-Fi SoC）。**
与 ch07 BLE 同属无线专题，同样**对本仓库是选读**——
F103 平台没有 Wi-Fi；ESP32/带 Wi-Fi 的板子进入硬件清单后再启动。

## 只看这一页（速览）

**主线一句话**：这章解决"F103 想上 Wi-Fi 怎么办"——先看 Zephyr 把 Wi-Fi 劈成管理面（异步 API + 事件回调）与数据面（连上后就是 ch08 的 socket）的分层（12.1），再比较三条外挂硬件路径怎么选（12.2），最后把两者串成跑通 TCP client 的最小配置清单（12.3），三篇是"API → 硬件 → 配置"的递进线。

| 小节 | 一句话结论 |
|---|---|
| 12.1 Wi-Fi 管理 API | Wi-Fi = 管理面（wifi_mgmt/net_mgmt 异步请求 + 事件）+ 数据面（普通 net_if 走 socket）两层完全解耦；事件回调跑在系统 workqueue 线程上下文 |
| 12.2 外挂方案对比 | ESP-AT modem / 原生 Wi-Fi SoC / SPI/SDIO 协处理器三条路在 Zephyr 里都抽象成 net_if、socket 代码一行不改；F103 现实替代是 W5500 |
| 12.3 Wi-Fi + socket 最小配置 | 最小配置 = ch08 网络栈 + CONFIG_WIFI/NET_MGMT_EVENT + DHCPv4；连接三步"注册回调 → 发请求 → k_sem_take 等结果"，连上后 socket 与 ch08 逐字节相同 |

**本章最容易踩的坑**：

- 事件回调里干长活/长日志：堵的是系统 workqueue，波及其他子系统（12.1）
- ssid_length 多算了结尾 '\0'：多算 1 就把终止符发进认证流程导致失败（12.3）
- 连上了但 socket 超时：DHCP 还没拿到地址就发数据，应等 IPv4 地址就绪事件（12.3）
- 事件回调从不触发：漏 CONFIG_NET_MGMT_EVENT=y 或忘了 add_event_callback（12.3）
- 把 ESP-AT 当完整网络栈用：socket offload 是功能子集，netstat/抓包这类本地栈能力缺（12.2）

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [12.1 Wi-Fi 管理 API](12.1-WiFi管理API.md) | 管理面/数据面分层、net_mgmt 异步事件、回调上下文纪律 | ✅ |
| [12.2 外挂方案对比](12.2-外挂方案对比.md) | ESP-AT modem vs 原生 SoC vs offload 协处理器；F103 替代（W5500） | ✅ |
| [12.3 Wi-Fi + socket 最小配置](12.3-WiFi与socket最小配置.md) | 最小 Kconfig、连接三步骨架、与 ch08 socket 的衔接 | ✅ |

## 读完本章你应该能回答

- Zephyr 的 Wi-Fi 管理 API 和网络栈（ch08）在哪一层对接？
- "ESP32 当 modem"和"直接用 ESP32 跑 Zephyr"两条路的取舍？
- Wi-Fi 连接事件走什么上下文回调？（回顾 ch04 线程模型）

## 前置 / 后续

- **前置**：[ch08 网络](../08-networking/README.md)
- **后续**：硬件清单扩到 Wi-Fi 板时再启动实验

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 全章无实验、无实测 | 无硬件；与 ch07 BLE 同为"硬件到位再启动"的选读章 |
| 12.3 配置未经验证 | 摘自官方 sample 语义整理；硬件到位后以 `samples/net/wifi` 实测校准 |
| 书 API 与新版有差 | 已按官方文档（Zephyr 3.x）校正（net_mgmt 请求框架、异步事件），12.1 内设对照表 |
