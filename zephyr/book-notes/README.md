# zephyr/book-notes —— 《Zephyr RTOS Embedded C Programming》配套笔记

> 状态：⬜ **骨架**（2026-10-09 建）。启动条件：stm32/01–06 + freertos/01–04 真机全通
> （Zephyr 抽象层厚，没有裸机 + 调度原理底子会被包死在框架里）。
> 写作规范与 stm32/book-notes 相同：一小节一篇、篇号与书章号对齐、
> 每篇带"原书怎么说 / 实测是什么"坑点表、头部互链对应实验。

## 配套教材（2026-10-09 调研）

| 项 | 内容 |
|---|---|
| 首选 | **《Zephyr RTOS Embedded C Programming: Using Embedded RTOS POSIX API》**（Andrew Eliasz, Apress 2024，677 页，ISBN 9798868801068） |
| 定位 | Zephyr 目前**唯一成体系的专门书**：架构 / 构建系统（west+Kconfig+devicetree）/ 多线程 / 消息队列·管道·邮箱·workqueue / 文件系统 / BLE / 网络 / ZBus / Renode 仿真 |
| 章节 | 12 章：① 导论 ② RTOS 基础复习 ③ 开发环境与构建原理 ④ 多线程 ⑤ 队列/管道/邮箱/workqueue ⑥ 文件系统 ⑦ BLE ⑧ Ethernet/WiFi/TCP-IP ⑨ DeviceTree（SPI/I2C）⑩ Renode ⑪ ZBus ⑫ Wi-Fi 专题 |
| 辅助 | **官方文档** [docs.zephyrproject.org](https://docs.zephyrproject.org)（质量高、随版本更新；书固定在 2024 版 API，冲突以官方文档为准） |
| 避坑 | 2025 年自费出版的《Zephyr RTOS for Embedded Developers》（Norms Albert，print-on-demand）内容浅、无出版社审校，**不建议作主线** |

## 章节 → 实验对位（规划）

| 书章节 | 对应实验 | 状态 |
|---|---|---|
| ch03 构建原理 + ch04 多线程 | [../01-hello](../01-hello/README.md) | ⬜ 骨架已建 |
| ch05 消息队列 | [../02-threads-msgq](../02-threads-msgq/README.md) | ⬜ 骨架已建 |
| ch04 信号量（同步） | [../03-semaphore](../03-semaphore/README.md) | ⬜ 骨架已建 |
| ch04 互斥量 + 优先级继承 | [../04-mutex-priority](../04-mutex-priority/README.md) | ⬜ 骨架已建 |
| ch09 DeviceTree | 贯穿（每个实验的 overlay 都用到） | — |
| ch06–08/10–12 | 后续追加（文件系统 / 网络 / Renode / ZBus） | ⬜ 未规划 |

- 回到：[zephyr/README](../README.md) ｜ 仓库顶层：[README](../../README.md)
