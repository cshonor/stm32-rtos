# ch06 · 文件系统 —— 章节导航

> 书第 6 章 · 对应实验：后续追加（骨架未建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的文件系统子系统：LittleFS / FAT 两套后端、挂载点、
以及和 Flash 分区（devicetree 里的 partitions）怎么挂钩。**
F103 只有 128K 片内 Flash、无文件系统需求，本章按"选读"处理——
但对将来上 SD 卡/外部 Flash 的项目是必修课。

## 只看这一页（速览）

**主线一句话**：本章解决"数据怎么安全落到 flash"——先看 FS 子系统的三层架构与选型口诀（flash 上 LittleFS、SD 卡上 FAT），再看分区表这张"地契"怎么划，最后看 LittleFS 凭什么同时做到掉电安全和磨损均衡。

| 小节 | 一句话结论 |
|---|---|
| 6.1 | 三层 = VFS 统一 API → LittleFS/FAT 后端 → flash/磁盘驱动；挂载 = 后端类型 + 分区 ID + 挂载点三要素 |
| 6.2 | 分区表是 devicetree 节点（偏移+长度，按擦除扇区对齐）；flash_area 是它到 C 代码的桥，FS/NVS/MCUboot 都站在上面 |
| 6.3 | LittleFS = 写时复制 + 日志 commit：任意掉电回到最近一致状态；代价是写放大，高频小写要攒批 |

本章最容易踩的坑：

- 挂载失败第一嫌疑是分区没格式化；但**别对存着数据的分区无脑 mkfs**（6.1 Q1）
- 分区长度不按擦除扇区对齐：LittleFS 以 sector 为单位擦除，跨半个 sector 就是灾难（6.2）
- 量产后改分区表 = 清盘：分区表属于"出厂前冻结"级别的设计（6.2 Q1）
- 改分区表后忘记重新 west build：链接地址由 devicetree 决定，不重编不生效（6.2 Q2）
- 每秒 fs_write 小数据：每次都触发 commit 和块管理，写放大严重；攒批或改用 FCB/NVS/settings（6.3 Q2）

## API 速查卡

| API / 命令 / 配置项 | 一句话作用 | 易错点 |
|---|---|---|
| `FS_LITTLEFS_DECLARE_DEFAULT_CONFIG(name)` | 生成绑定 storage_partition 的默认配置 | 依赖 dts 里存在 `storage_partition` 节点 |
| `fs_mount` | 把后端 + 分区挂到挂载点 | 失败第一嫌疑是没格式化；但别无脑 mkfs |
| `fs_mkfs` | 把分区格式化成空文件系统 | 会清盘，只对确认无数据的分区用 |
| `fs_open` / `fs_read` / `fs_write` / `fs_close` | POSIX 风格文件读写 | 路径前缀必须匹配挂载点；FAT 卷名带冒号（`/SD:`） |
| `CONFIG_LOG_BACKEND_FS` | LOG 子系统落盘后端（黑匣子） | 高频日志注意写放大（见 6.3） |
| `settings_save` / `settings_load` | 键值对参数持久化 | 存参数到这就够，别手写 fs API |
| `partitions`（dts 节点） | flash 划地声明：偏移 + 长度 | 长度按擦除扇区对齐；改后必须重新 west build |
| `FIXED_PARTITION_ID(name)` | 分区节点 → 编译期数字 ID | label 字符串查询已废弃 |
| `flash_area_open` / `flash_area_read/write/erase` | 不挂文件系统裸读写分区 | `fa_off` 相对 flash 基址；erase 按扇区对齐 |
| NVS / FCB | 比 FS 更轻的掉电安全存储 | 键值对选 NVS，只进不出的流水选 FCB |
| `CONFIG_FS_LITTLEFS_FC_HEAP_SIZE` | LittleFS 元数据缓存大小 | 影响 RAM 占用与性能；分区要留空闲块余量 |

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
