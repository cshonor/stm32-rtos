# ch12 · Wi-Fi 专题 —— 章节导航

> 书第 12 章 · 对应实验：选读（F103 无 Wi-Fi）
> 章导航：本篇

## 本章讲什么

**Zephyr 的 Wi-Fi 支持：扫描/连接管理 API、Wi-Fi 驱动模型、
常见外挂方案（ESP32 作 modem / 原生 Wi-Fi SoC）。**
与 ch07 BLE 同属无线专题，同样**对本仓库是选读**——
F103 平台没有 Wi-Fi；ESP32/带 Wi-Fi 的板子进入硬件清单后再启动。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 12.1 | Wi-Fi 管理 API：scan / connect / status 回调 | ⬜ |
| 12.2 | 外挂方案对比：ESP-AT modem vs 原生 SoC vs 换板 | ⬜ |
| 12.3 | Wi-Fi + socket：跑通一个 TCP client 的最小配置 | ⬜ |

## 读完本章你应该能回答

- Zephyr 的 Wi-Fi 管理 API 和网络栈（ch08）在哪一层对接？
- "ESP32 当 modem"和"直接用 ESP32 跑 Zephyr"两条路的取舍？
- Wi-Fi 连接事件走什么上下文回调？（回顾 ch04 线程模型）

## 前置 / 后续

- **前置**：[ch08 网络](../08-networking/README.md)
- **后续**：硬件清单扩到 Wi-Fi 板时再启动

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 全章未写 | 无硬件；与 ch07 BLE 同为"硬件到位再启动"的选读章 |
