# ch06 · 文件系统 —— 章节导航

> 书第 6 章 · 对应实验：后续追加（骨架未建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的文件系统子系统：LittleFS / FAT 两套后端、挂载点、
以及和 Flash 分区（devicetree 里的 partitions）怎么挂钩。**
F103 只有 128K 片内 Flash、无文件系统需求，本章按"选读"处理——
但对将来上 SD 卡/外部 Flash 的项目是必修课。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 6.1 | FS 子系统架构：VFS → LittleFS/FAT → flash 驱动 | [6.1-FS子系统架构](6.1-FS子系统架构.md) |
| 6.2 | devicetree 分区表：flash 怎么切成 boot / app / storage | [6.2-devicetree分区表](6.2-devicetree分区表.md) |
| 6.3 | 磨损均衡与掉电安全：LittleFS 为什么是小 Flash 的标配 | [6.3-磨损均衡与掉电安全](6.3-磨损均衡与掉电安全.md) |

## 读完本章你应该能回答

- Zephyr 里"挂一个文件系统"从 devicetree 到 mount 调用经过哪几层？
- LittleFS 相对 FAT 在小容量 Flash 上的两个决定性优点？
- 文件系统分区和 bootloader（MCUboot）分区怎么共存？

## 前置 / 后续

- **前置**：[ch09 DeviceTree](../09-devicetree/README.md)（分区表是 devicetree 节点）
- **后续**：与日志/参数存储类需求一起出现时补实验

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实验、无实测输出 | F103 无文件系统需求；列为选读，SD 卡/外部 Flash 项目启动时补 |
| 书 API 与新版有差 | 已按官方文档校正（FIXED_PARTITION 宏、LittleFS 默认配置宏等） |
