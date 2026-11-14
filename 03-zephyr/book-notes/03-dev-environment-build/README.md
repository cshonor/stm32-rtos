# ch03 · 开发环境与构建原理 —— 章节导航

> 书第 3 章 · 对应实验：[`03-zephyr/01-hello`](../../01-hello/README.md)（⬜ 骨架已建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的"三件套"——west（仓库与构建编排）、Kconfig（功能配置）、
devicetree（硬件描述）——如何合力把一个应用编出来。**
这是 Zephyr 学习曲线最陡的一段，也是它和 FreeRTOS 工程形态的最大差异：
FreeRTOS 是"把几个 .c 加进你的 Makefile"，Zephyr 是"把你的应用挂进它的构建系统"。

与 LDD- 侧的关联直接拉满：Kconfig 和 devicetree 就是 Linux 内核的同一套机制
（`LDD-/09` 设备树章），语法零迁移成本。

## 只看这一页（速览）

**主线一句话**：本章解决"一个 Zephyr 应用怎么被编出来"——west 管源码拼装与命令转发，三个文件定应用输入，Kconfig 依赖树求解决定功能开关，build 目录里的产物则是日后调试排查的案发现场。

| 小节 | 一句话结论 |
|---|---|
| 3.1 | west 是 meta-tool，自己几乎不实现：构建转交 CMake/Ninja，烧录转交 runner，换调试器不改命令 |
| 3.2 | 最小骨架三文件（CMakeLists.txt + prj.conf + main.c）；构建 = 应用/板卡/内核三方输入合成，别手写顶层 Makefile |
| 3.3 | 链路：prj.conf → 依赖树求解 → .config → autoconf.h；写了不生效九成是依赖没满足 |
| 3.4 | 三份真相文件（.config / zephyr.dts / zephyr.map）是排查起点；配置灵异现象先 pristine |

本章最容易踩的坑：

- 写了 CONFIG、编译通过、功能就是不出来：被 depends on 静默丢弃，menuconfig 里 `/` 搜符号看 Depends on（3.3）
- 改了 prj.conf 行为没变：配置缓存和新输入打架，`west build -t pristine` 从零重来（3.4）
- 在模块仓库里改了代码，west update 一切版本全冲突：模块当只读依赖用，改动走 fork + manifest 指向（3.1 Q2）
- CMakeLists.txt 里 `project()` 写在 `find_package(Zephyr)` 之前——顺序是硬要求（3.2）
- 设备不工作、引脚不对时到处加打印，而不先查 zephyr.dts 这份"硬件真相"（3.4 Q2）

## API 速查卡

| API / 命令 / 配置项 | 一句话作用 | 易错点 |
|---|---|---|
| `west init -m <仓库> <目录>`（3.1） | 建工作区，克隆 manifest 仓库 | 只拉了清单仓库，模块还要 `west update` |
| `west update`（3.1） | 按 west.yml 把所有模块摆到位 | 模块仓库当只读依赖，里面有未提交改动会冲突 |
| `west build -b <板> <app>`（3.1） | 构建（转交 CMake + Ninja） | 板名以官方板卡页为准 |
| `west flash` / `west debug`（3.1） | 烧录 / 调试（转交板级 runner） | 换调试器用 `-r <runner>`，命令本身不变 |
| `west build -t menuconfig`（3.1/3.3） | 图形化改配置，`/` 搜符号 | 退出保存只影响本次 build 目录，持久要落回 prj.conf |
| `find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})`（3.2） | 把内核构建系统拉进工程 | `project()` 必须排在它**之后**，硬要求 |
| `target_sources(app PRIVATE ...)`（3.2） | 源文件挂到 app 目标 | 多文件一行列全或分多次调用 |
| `app.overlay` / `boards/<板>.overlay`（3.2） | 应用层 dts 补丁 | 板名匹配的只对某板生效 |
| `boards/<板>.conf`（3.2） | 只对某板生效的 Kconfig 片段 | 与 prj.conf 冲突时**它赢**（更具体的赢） |
| `IS_ENABLED(CONFIG_X)`（3.3） | 判断符号是否开启 | 未开启的符号在 autoconf.h 里不生成，别指望 `#ifdef` 总有定义 |
| `west build -t clean` / `-t pristine`（3.4） | 清中间产物 / 全清从零配置 | 配置灵异现象先 pristine |
| `west build -t rom_report` / `ram_report`（3.4） | 按模块聚合的体积报告 | 裁剪先看 report 找大户，再回 zephyr.map 查符号 |

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 3.1 | west：manifest、init/update、build/flash/debug 一条链 | [3.1-west是什么](3.1-west是什么.md) ✅ |
| 3.2 | 一个 Zephyr 应用的最小骨架：CMakeLists.txt + prj.conf + app.overlay | [3.2-应用最小骨架](3.2-应用最小骨架.md) ✅ |
| 3.3 | Kconfig 怎么工作：prj.conf → autoconf.h；menuconfig 看什么 | [3.3-Kconfig怎么工作](3.3-Kconfig怎么工作.md) ✅ |
| 3.4 | 构建产物解剖：zephyr.elf / merged.hex / build 目录里都有啥 | [3.4-构建产物解剖](3.4-构建产物解剖.md) ✅ |

## 读完本章你应该能回答

- `west build -b nucleo_f103rb app` 背后依次发生了哪几步？
- prj.conf 里 `CONFIG_GPIO=y` 最终怎么变成代码里的 `#define`？
- 应用级的 devicetree overlay 是怎么"叠"到板级 dts 上的？
- 为什么 Zephyr 工程不该手写顶层 Makefile？

## 前置 / 后续

- **前置**：[01-stm32/book-notes ch11 链接器](../../../01-stm32/book-notes/11-linker/README.md)
  （构建的终点还是链接脚本和段布局，底子在裸机篇）
- **后续**：[ch04 多线程](../04-multithreading/README.md)（实验 01 的理论）→
  [ch09 DeviceTree](../09-devicetree/README.md)（三件套里最深的那个）

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测构建日志 | 01-hello 未做；3.4 的产物地图按官方文档描述，真实日志待实验落地后解剖补图 |
| 书基于 2024 工具链 | west/Zephyr SDK 版本差异以官方文档为准；已在 3.1/3.3 用"原书怎么说/实际是什么"表标注 |
