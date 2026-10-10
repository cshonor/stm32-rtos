# 03-zephyr/book-notes —— 《Zephyr RTOS Embedded C Programming》配套笔记

> 状态：🔨 **已开工**（2026-10-09）。章导航 12 章已齐；ch04 小节笔记已写满，
> 其余章小节随实验推进逐章补。
> 写作规范与 01-stm32/book-notes 相同：一小节一篇、篇号与书章号对齐、
> 每篇带"原书怎么说 / 实测是什么"坑点表与折叠 Q&A、头部互链对应实验。
> ⚠ 启动条件未达成（01-stm32/01–06 + 02-freertos/01–04 未全通），现阶段笔记只讲机制，
> **且内容以 [Zephyr 官方文档](https://docs.zephyrproject.org) 为准**——
> 书固定在 2024 年 API，冲突处记进"原书怎么说 / 实际是什么"表。

## 配套教材

| 项 | 内容 |
|---|---|
| 首选 | **《Zephyr RTOS Embedded C Programming: Using Embedded RTOS POSIX API》**（Andrew Eliasz, Apress 2024，677 页，ISBN 9798868801068） |
| 定位 | Zephyr 唯一成体系的专门书：构建系统（west+Kconfig+devicetree）/ 多线程 / IPC / 文件系统 / BLE / 网络 / ZBus / Renode |
| 辅助 | **官方文档**（随版本更新；书的 API 有年代差，以它为准绳） |
| 避坑 | 2025 自费出版《Zephyr RTOS for Embedded Developers》（Norms Albert）不作主线 |

## 章节导航（书章号）

| 章 | 主题 | 章导航 | 小节进度 | 对应实验 |
|---|---|---|---|---|
| ch01 | 导论 | [01-introduction](01-introduction/README.md) | ⬜ 0 篇 | 贯穿 |
| ch02 | RTOS 基础复习 | [02-rtos-fundamentals](02-rtos-fundamentals/README.md) | ⬜ 0 篇 | 与 02-freertos/01–04 对照 |
| ch03 | 开发环境与构建原理 | [03-dev-environment-build](03-dev-environment-build/README.md) | ⬜ 0 篇 | [01-hello](../01-hello/README.md)（west 构建） |
| ch04 | 多线程 | [04-multithreading](04-multithreading/README.md) | ✅ **6 篇写满** | [01-hello](../01-hello/README.md) |
| ch05 | 队列/管道/邮箱/workqueue | [05-ipc-workqueues](05-ipc-workqueues/README.md) | ⬜ 0 篇 | [02-threads-msgq](../02-threads-msgq/README.md) |
| ch06 | 文件系统 | [06-filesystems](06-filesystems/README.md) | ⬜ 0 篇 | 后续追加 |
| ch07 | BLE | [07-ble](07-ble/README.md) | ⬜ 0 篇 | F103 无 BLE，选读 |
| ch08 | Ethernet/WiFi/TCP-IP | [08-networking](08-networking/README.md) | ⬜ 0 篇 | 后续追加 |
| ch09 | DeviceTree（SPI/I2C） | [09-devicetree](09-devicetree/README.md) | ⬜ 0 篇 | 贯穿（每个实验的 overlay） |
| ch10 | Renode 仿真 | [10-renode](10-renode/README.md) | ⬜ 0 篇 | 无板替代路径 |
| ch11 | ZBus | [11-zbus](11-zbus/README.md) | ⬜ 0 篇 | 后续追加 |
| ch12 | Wi-Fi 专题 | [12-wifi](12-wifi/README.md) | ⬜ 0 篇 | F103 无 Wi-Fi，选读 |

## 与 freertos 轨的对照关系

Zephyr 是**第二遍**：02-freertos/01–04 的四个实验在 03-zephyr/ 有一一对应的重做
（任务→线程、队列→msgq、信号量→k_sem、互斥量+优先级→k_mutex）。
笔记里也保留"与 FreeRTOS 对照"小节——**学两遍 = 记两遍**。

- 回到：[03-zephyr/README](../README.md) ｜ 仓库顶层：[README](../../README.md)
