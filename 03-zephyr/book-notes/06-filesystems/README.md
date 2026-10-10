# ch06 · 文件系统 —— 章节导航

> 书第 6 章 · 对应实验：后续追加（骨架未建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的文件系统子系统：LittleFS / FAT 两套后端、挂载点、
以及和 Flash 分区（devicetree 里的 partitions）怎么挂钩。**
F103 只有 128K 片内 Flash、无文件系统需求，本章按"选读"处理——
但对将来上 SD 卡/外部 Flash 的项目是必修课。

## 小节清单（规划，⬜ 待写）

| 小节 | 标题 | 状态 |
|---|---|---|
| 6.01 | FS 子系统架构：VFS 层 → LittleFS/FAT 后端 → flash 驱动 | ⬜ |
| 6.02 | devicetree 分区表：boot 槽 / 应用 / 存储区怎么划 | ⬜ |
| 6.03 | 磨损均衡与掉电安全：LittleFS 为什么是小 Flash 的标配 | ⬜ |

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
| 小节未写、无实验 | F103 无需求；列为选读 |
