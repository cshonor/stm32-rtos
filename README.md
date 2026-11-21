# STM32- · STM32 + FreeRTOS + Zephyr 学习仓库

> **定位：一条 freestanding（无操作系统）C 的学习路径。**
> 从"没有 OS，C 怎么碰到硬件"起步，经裸机 → 库 → RTOS → 工程化 RTOS 一路往上搭，
> 全程都待在 C 标准说的 **freestanding 执行环境**里（入口、启动、标准库都自己定，
> 不像 hosted 程序那样有 OS 托着）。与 `LDD-`（Linux 驱动轨，跑在 hosted + 内核态）
> 互补不混线——**一条学"自己站着"，一条学"寄宿在 OS 里"**。
> 概念源头见 [00.1 没有操作系统的 C 语言（freestanding）](01-stm32/00-mental-model/00.1-没有OS的C语言.md)。
> **三条轨道各配一本书：笔记章节直接平铺在各轨道目录下（一打开就是 ch01、ch02…），
> 实验收在各轨道的 `labs/` 里**：
>
> | 轨道 | 配套教材 | 笔记位置 |
> |---|---|---|
> | `01-stm32/`（裸机 → 库 → HAL） | **《裸机C编程：嵌入式系统C程序设计》**（[美] Stephen Oualline 著，黄俊彬 译，机械工业出版社 2025，ISBN 9787111792017；原书 *Bare Metal C*, No Starch 2022，全 18 章） | [01-stm32/](01-stm32/README.md)（✅ 已写完） |
> | `02-freertos/`（RTOS 第一遍） | **《Mastering the FreeRTOS Real Time Kernel》**（Richard Barry，FreeRTOS 官方书，官网免费 PDF，有社区中译本；纸质备选：野火刘火良《FreeRTOS 内核实现与应用开发实战指南——基于STM32》） | [02-freertos/](02-freertos/README.md)（✅ 已写满：12 章 44 篇，先行讲解——实验未做、实测数据待补） |
> | `03-zephyr/`（工程化第二遍） | **《Zephyr RTOS Embedded C Programming: Using Embedded RTOS POSIX API》**（Andrew Eliasz, Apress 2024，677 页——Zephyr 唯一成体系的专门书；辅以官方文档） | [03-zephyr/](03-zephyr/README.md)（✅ 已写满：12 章 43 篇，先行讲解——API 以官方文档为准绳） |
>
> `01-stm32/` 的篇号 **chNN 与书的章号一一对齐**（ch01–ch18 + 补充篇），
> 本篇下面的"学习路线"表按**实验**编号，两者的映射见 `01-stm32/README.md`。
> 预习衔接：`LDD-/09` 学过中断下半部、`10` 章（规划中）Pi 5 裸机
> 会先走一遍"上电 → 启动 → main → 寄存器"，到这里换地址表就是 STM32 本体。

## 这是一条 freestanding 学习路径

C 标准只定义两种执行环境（N1570 §5.1.2p1）：**hosted**（有 OS 托管，`main` 签名固定、
标准库全套保证）和 **freestanding**（实现自己定义启动/入口/终止，标准库只保证 `<stddef.h>`
等一小撮头文件）。本仓库从头到尾都在后者——**没有一行代码跑在操作系统上**。
把三本书按"在 freestanding 环境里往上叠了什么"排开，就是这条路径的主线：

| 站 | 目录 | 在 freestanding 之上多了什么 | 入口/启动谁负责 | 学完能回答 |
|---|---|---|---|---|
| 前提 | `01-stm32/00-mental-model` | 还没有代码——先钉住"freestanding 是什么、C 怎么碰硬件" | — | 没 OS 的 C 凭什么能操作寄存器 |
| 第 1 站 | `01-stm32/`（裸机 C，ch01–ch18） | 从零起步：`-nostdlib`、自己写 `Reset_Handler`/向量表/链接脚本，printf 自己 retarget 到 UART | **你自己**（crt0 + 链接脚本） | 上电到 main 之间发生了什么 |
| 第 2 站 | `01-stm32/labs/02-libopencm3`、`03-hal` | 仍是 freestanding，只是寄存器操作交给库；换板子不改业务逻辑 | 还是你（库不改启动） | 裸机寄存器 vs 库 vs HAL 差在哪 |
| 第 3 站 | `02-freertos/` | 叠一个**抢占式调度器**：任务/队列/信号量/中断管理——但内核下面依旧没有 OS | 你的启动代码先跑，再把控制权交给调度器 | 没有 OS 怎么实现"同时"跑多件事 |
| 第 4 站 | `03-zephyr/` | 工程化 RTOS：devicetree + Kconfig + west，把前几站的手工配置变成描述文件 | Zephyr 的启动链（仍是 freestanding） | 量产项目怎么组织一个 freestanding 工程 |

**为什么用 freestanding 统摄而不是"裸机→RTOS"**：后者只描述了技术栈的堆叠顺序，
freestanding 描述的是**这条路的本质约束**——从第一站到最后一站，"没有 OS 托管"
这个前提一次都没变，变的只是"在这片空地上自己搭到多高"。三本书的分工因此是：
第 1 站回答**地基怎么打**（C 直接落硬件），第 2 站回答**要不要借轮子**（库/HAL），
第 3 站回答**并发怎么办**（调度器），第 4 站回答**工程怎么规模化**（配置系统）。
概念辨析（freestanding vs hosted、名字为什么叫"自己站着"）在
[00.1](01-stm32/00-mental-model/00.1-没有OS的C语言.md)，别在这里重复。

**和另一条轨的分界**：`LDD-`（Linux 驱动）、TLPI（系统编程）都跑在 **hosted** 环境——
起止由 OS 管、有完整 libc、`file_operations`/`request_irq` 由内核提供。同一个概念
（中断、内存、并发）在两条轨各学一遍：freestanding 这边看"从零自己造"，
hosted 那边看"OS 已经给你造好了、你只要按接口用"。详见文末
「与 LDD- 轨的概念对照（学两遍 = 记两遍）」一节。

## 目录结构

```
tools/        工具台：环境自检 / 烧录 / 调试 / 生成新实验（说明见 tools/README.md）
mk/           构建层：一份共享的 CFLAGS/LDFLAGS/规则，各 lab 的 Makefile 缩到 4 行
boards/       板级层：CPU / 内存布局 / OpenOCD 配置 / LED 引脚，换板子只动这里
hardware/     硬件采购：两块板板载资源盘点 + 外设必买/按需买清单（说明见 hardware/README.md）
01-stm32/        《裸机C编程》笔记：章节平铺（00-mental-model → 21-clock-tree + 附录，
                 篇号 = 书章号；00-mental-model 是读书前的三篇前提笔记）
  labs/        实验线：00-toolchain-clang（clang 工具链）→ 01-bare-metal（裸机C，主线）→
                 02-libopencm3（库）→ 03-gpio-blink / 03-hal → 04-uart-printf → 05-exti-button → 06-timer
                 → 07-hello（工具台参考实验：Makefile 只有 4 行的最小可跑工程）
02-freertos/     《Mastering the FreeRTOS Real Time Kernel》笔记：章节平铺（01–12，✅ 已写满 44 篇）
  labs/        FreeRTOS 移植与任务实验 01–04（等裸机三件套通了再进）
03-zephyr/       《Zephyr RTOS Embedded C Programming》(Eliasz) 笔记：章节平铺（01–12，✅ 已写满 43 篇）
  labs/        Zephyr 实验 01–04（第二遍的工程化路线，最后走）
third_party/  git 子模块：libopencm3（01-stm32/labs/02-libopencm3 用；clone 后先 git submodule update --init）
_refs/        只作参考的上游克隆，不进版本库（如 libopencm3-examples）
```

## 工具台（toolbench）

书 1.2 让装 **System Workbench for STM32** —— 它解决的问题是"新手要同时搞定编译器、
构建系统、烧录器、调试器四件事，任何一环配错都表现为点灯不亮"。这个仓库不要那个
Eclipse 壳，把同一件事拆成三层，每层可单独替换、每步看得见：

```bash
bash tools/env.sh                 # 这台机器现在能不能做嵌入式（8 层逐层真跑一遍）
source tools/env.sh --export      # 工具不在 PATH 上时先做这一步
cd 01-stm32/labs/07-hello && make      # 编译一个最小工程
make flash                        # 插上板子再烧
../../../tools/dbg.sh hello.elf   # 一条命令起 openocd + gdb，退出时自动收摊
tools/newlab.sh 01-stm32/labs/08-uart  # 生成下一个实验的骨架（板级参数自动填好）
```

| 层 | 目录 | 职责 | 变动频率 |
|---|---|---|---|
| 脚本 | `tools/` | 环境自检（`env.sh`，把 1.2 的分层确认表变成可执行脚本）、烧录、调试、生成新实验 | 加工具时 |
| 构建 | `mk/` | 共享的 CFLAGS/LDFLAGS/规则/烧录调试命令 | 改编译选项时 |
| 板级 | `boards/` | CPU、内存布局、OpenOCD 配置、LED 引脚 | 换板子时 |

各 lab 的 Makefile 从此只有四行（声明"我是谁、用什么板子"），
完整说明见 [`tools/README.md`](tools/README.md)，板级字段与新增板子的步骤见
[`boards/README.md`](boards/README.md)。

## 学习路线（书章节 → 实验）

| # | 书主题 | 对应实验 | 状态 |
|---|---|---|---|
| 0 | 工具链（**不用 GCC**：clang + ld.lld + llvm 二进制工具） | 01-stm32/labs/00-toolchain-clang | ✅ 主机侧实测 |
| 1 | 开发环境（烧录链路 + OpenOCD/ST-Link） | 01-stm32/labs/01-bare-metal | ✅ **真机实测（09-26 烧录 + 回读 + gdb 源码级停住）** |
| 2 | 启动文件、向量表、上电到 main | 01-stm32/labs/01-bare-metal | ✅ **真机实测（09-26 向量表/RAM 回读与 ELF 逐字节一致）** |
| 3 | 链接脚本（Flash/RAM 布局） | 01-stm32/labs/01-bare-metal（linker.ld 逐段 + nokeep 反面教材） | ✅ 真机实测（笔记：[11-linker](01-stm32/11-linker/README.md)） |
| 4 | 寄存器与 CMSIS 头（GPIO 点灯） | 01-stm32/labs/03-gpio-blink | ✅ 真机实测（烧录 Verified OK、gdb 单步、portprobe 探针） |
| 5 | 时钟树与 UART | 01-stm32/labs/04-uart-printf | ⬜ 骨架已建（笔记：书 ch09 + 补充 ch21） |
| 6 | 中断与 EXTI | 01-stm32/labs/05-exti-button | ⬜ 骨架已建（笔记：书 ch10 + ch05） |
| 7 | SysTick / 定时器 | 01-stm32/labs/06-timer | ⬜ 骨架已建（笔记：补充 ch19） |
| 8 | FreeRTOS：任务/调度/队列/信号量 | 02-freertos/labs/01–04 | ⬜ 骨架已建（笔记：[02-freertos/ 12 章](02-freertos/README.md) 已写满；裸机前置见 [补充 ch20](01-stm32/20-towards-freertos/README.md)） |
| 轨道二 | 库路线：libopencm3（≠ HAL） | 01-stm32/labs/02-libopencm3 | ✅ 真机首烧通过（09-24） |
| 轨道三 | ST 官方 HAL | 01-stm32/labs/03-hal | ⬜ 骨架已建，库未引入 |

**书的逐章笔记**：`01-stm32/` 已全部按「一小节一笔记」写完 —— **ch01–ch18 + 附录
+ 补充篇 ch19（SysTick/定时器）/ ch20（走向 FreeRTOS）/ ch21（时钟树）**，
每篇带"原书怎么说 / 实测是什么"坑点表与折叠 Q&A。想按书推进就看那个索引，
想按实验推进就看上面这张表。

**第二遍（工程化路线）**：stm32 + freertos 全通后进 `03-zephyr/`——devicetree / Kconfig /
west 与 Linux 机制同源，实验与 02-freertos/ 一一对照，规划见 `03-zephyr/README.md`。

## 面试备战（MCU 物联网岗 · 2026-11）

> 目标岗位画像：小团队机器人/IoT 公司，MCU 固件岗（C + STM32 + UART/RS485/CAN/I2C/SPI +
> MQTT + OTA + 看原理图）。
> 诊断结论：**本仓库笔记能撑「技术深挖」，撑不起「项目故事」**——I2C/SPI/RS485/MQTT/OTA
> 在笔记里只有提及、没有作品。以下按面试必考 5 题补：读什么、买什么、做什么。

### 要读的笔记（按面试题组织）

| 面试题 | 读什么 | 补什么 |
|---|---|---|
| ① I2C/SPI 怎么驱动传感器 | [03 章寄存器读写](01-stm32/03-embedded-system-programming/README.md) + [06 章指针数组](01-stm32/06-arrays-pointers-strings/README.md) + [04 章位操作](01-stm32/04-numbers-and-bitops/README.md) | I2C 时序图另找一篇看熟（能徒手画一次完整读操作） |
| ② UART/RS485 帧处理、粘包、校验 | [09 章串口](01-stm32/09-uart-serial/README.md) + [10 章中断](01-stm32/10-interrupts/README.md) + [freertos 04 队列](02-freertos/04-queue-management/README.md)（ISR 收字节→队列→任务解包 = 标准答案） | RS485 话术骨架：**UART + DE/RE 方向切换 + 差分总线 + Modbus 帧（地址/功能码/数据/CRC16）**；粘包答「超时断帧或帧头+长度」 |
| ③ 看原理图、万用表排错 | 笔记帮不了，动手活 | 实验 0 攒真实排错故事 |
| ④ OTA 升级、断电保护 | [11 章链接器](01-stm32/11-linker/README.md)（双分区跳转全靠链接脚本）+ [zephyr 06 文件系统](03-zephyr/06-filesystems/README.md)（掉电安全/磨损均衡） | 话术骨架：Bootloader + A/B 双分区 → 下载到备用区 → CRC 校验 → **标志位最后写**（任何时刻断电都回得去） |
| ⑤ MQTT 上云、断线重连 | [zephyr 08 网络](03-zephyr/08-networking/README.md) + [12 WiFi](03-zephyr/12-wifi/README.md) + [freertos 09 通知](02-freertos/09-task-notifications/README.md) | 背五个词：Broker/Pub/Sub/QoS/KeepAlive；重连答「KeepAlive 超时 + 指数退避 + 重订阅 + QoS1 补发」 |
| 通用打底 | [19 章 SysTick/定时器](01-stm32/19-systick-and-timer/README.md)（PWM = 电机控制入场券）+ [freertos 03 任务调度](02-freertos/03-task-management/README.md) + [21 章时钟树](01-stm32/21-clock-tree/README.md) | — |

### 要买什么（已按 [hardware/README.md](hardware/README.md) 修正）

**F407 探索者板载已经有 MPU6050 / 24C02（I2C）、SP3485（RS485）、TJA1050（CAN）——
传感器和总线硬件都不用买。** 真正缺的只有：

| 买什么 | 参考价 | 用途 |
|---|---|---|
| ESP32-C3 开发板（Type-C） | ¥20–35 | 实验 2 的 MQTT 主角，自带 WiFi + USB 串口 |
| 杜邦线 + 面包板 + 克隆 ST-Link + 逻辑分析仪 | ≈¥55–100 | hardware 必买四件，**若还没买则优先**，逻辑分析仪是调 I2C 时序的唯一现实手段 |
| 万用表入门款 | ¥30–60 | 可选，题 3 道具（初期 gdb `mdw` 读寄存器能顶） |

### 要做的实验

| # | 内容 | 时间 | 对应题 |
|---|---|---|---|
| 0 | 万用表 + 原理图热身：找 NUCLEO 原理图定位 USART2/I2C 引脚，量通断，**故意制造一次 SDA 断开故障**记录排查过程 | 半天 | ③ |
| 1 | **I2C 传感器采集**：day1 扫地址 → day2 读数据串口打印 → day3 自定义帧（帧头+长度+CRC8）→ day4 改中断收 + FreeRTOS 队列解耦。两条路线任选：**F407 板载 MPU6050**（零采购）或 F103 + 另购 AHT20（¥10） | 3–5 天 | ①② |
| 2 | **ESP32-C3 MQTT 上云**：连公共 broker（如 broker.emqx.io）发数据 → 拔路由器练断线重连（指数退避 + 重订阅 + QoS1 补发，留日志截图）→ 进阶：F103/F407 经 UART 发帧给 ESP32 上云，串成「采集→传输→上云」完整项目故事 | 2–3 天 | ⑤ |
| 3 | RS485 + OTA 话术腹稿各 200 字讲两遍；RS485 想真做可用 F407 板载 SP3485（需对端节点） | 0–1 天 | ②④ |

时间预算：等快递期间读笔记（2–3 天）→ 实验 0→1→2（5–8 天）→ 面试前一天把项目串成
3 分钟陈述。**总计约 1.5–2 周**，产出 = 简历上一行「STM32 传感器采集 + UART 帧协议 +
ESP32 MQTT 上云（I2C/UART/中断/FreeRTOS）」。

## 与 LDD- 轨的概念对照（学两遍 = 记两遍）

| 概念 | Linux 轨（LDD-） | MCU 轨（本仓库） |
|---|---|---|
| 设备访问 | `/dev` 节点 + file_operations | 直接 MMIO 寄存器 |
| 中断 | request_irq + 下半部 | NVIC + EXTI + ISR（自身就是"上半部"，慢活用 RTOS 任务） |
| 内存 | kmalloc/vmalloc | 静态分配 + 链接脚本定死 |
| printf | 用户态 libc | 自己移植 UART retarget |

## 硬件

- 外设该买什么、别买什么：见 [`hardware/README.md`](hardware/README.md)
  （必买只有四件：杜邦线 / 面包板 / 克隆版 ST-Link V2 / 8 通道逻辑分析仪，合计 ≈¥55–100；
  F407 探索者板载已覆盖 I2C / SPI / ADC / CAN / RS485 / 以太网 / USB / 音频 / RTC）
- 板 1（已到手）：**NUCLEO-F103RB**（ST 官方 Nucleo-64）
  - 板载 ST-Link/V2-1（macOS 免驱可直接用 openocd），用户 LED = **PA5**（LD2），
    128K Flash / 20K RAM，`_stack` = 0x20005000
  - 是 `01-stm32/labs/02-libopencm3` 的默认配置（`DEVICE=stm32f103rb`，无需覆盖）
- 板 2（正点原子 **F407 探索者**，STM32F407ZGT6）
  - 168MHz / Cortex-M4F（带 FPU）/ 1MB Flash / 192KB RAM；LED0 = **PF9**、LED1 = PF10（低电平点亮）
  - 接入步骤：① 库要重编家族 `make -C third_party/libopencm3 TARGETS=stm32/f4`；
    ② 工程 `make DEVICE=stm32f407zg`（genlink 生成对应 ld，ROM 1M / RAM 128K+64K CCM）；
    ③ main.c 的 LED 从 PA5 改成 PF9；④ F407 上电默认 HSI 16MHz，点灯够用，
    要跑满 168MHz 需配 PLL（libopencm3 的 `rcc_clock_setup_pll`）
  - 调试走 SWD 排针 + 外接 ST-Link（`openocd/generic-stlink-f103.cfg` 的思路同款，
    target 换 `stm32f4x.cfg`）
- 调试：ST-Link V2
  - OpenOCD 已装（xpack 0.12.0 darwin-arm64 原生构建，2.3 MB），脚本根在
    `~/.local/xpack-openocd-0.12.0-7/openocd/scripts`
  - 烧录配置两份：`01-stm32/labs/02-libopencm3/openocd/f103rb.cfg`（NUCLEO 板载 ST-Link）、
    `01-stm32/labs/02-libopencm3/openocd/generic-stlink-f103.cfg`（外接 ST-Link + 裸板）
- 交叉链（两条，按 lab 选）：
  - **不用装 GCC 的一条**（01-stm32/labs/00–01）：Mac 端实测走 micromamba `cdev` 里的
    clang 23.1.0 + ld.lld 23.1.0 + llvm-objcopy/objdump/readelf，全程 `-nostdlib`，
    产出 296 字节可烧写镜像。踩过的坑见 `01-stm32/labs/00-toolchain-clang/README.md`
  - **GNU 一条**（01-stm32/labs/02-libopencm3 及以后用库的场合）：Arm GNU Toolchain 14.2.Rel1
    （darwin-arm64 官方包，装在 `~/.local/arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi/`），
    libopencm3 的官方目标就是它
    - 本机没有 WSL / apt / docker，conda-forge 也没有 arm-none-eabi →
      只能"官方 tar 包 + 家目录"，不碰 `/opt`、`/usr/local`
    - `/usr/bin/python3` 会弹 Xcode 许可协议，genlink.py 需要 PATH 里有能用的 python3
  - **工具在哪不写死**：`bash tools/env.sh` 会翻 micromamba / Homebrew / `~/.local` /
    Windows 的 `Program Files` 等位置并报告结果（Windows 实测走 `C:\Program Files\LLVM`，
    clang 22.1.8）。Makefile 侧不做路径搜索，契约是"PATH 里有什么就用什么"

## 纪律（沿用 LDD- 惯例）

- 每个实验必须真机跑通再写笔记，实测输出贴进对应 README
- **笔记进书目录根（章节平铺），实验进 `labs/`；lab README 只写实验指南**（文件/构建/实测输出/坑点）+
  笔记落点索引；概念性内容不堆在 lab README 里（2026-10-11 起，
  00-toolchain-clang 已按此瘦身）
- 坑点记录进各 lab README，"原书怎么说 / 实际是什么"分开写
- 工具链/库这类"环境事实"写进本文件，避免每个 lab 重复踩
- GPL 只在内核语境存在；MCU 裸机无许可证负担（FreeRTOS 是 MIT，libopencm3 是 LGPL-3.0
  / GPL-3.0——**静态链接它会带上 LGPL 的义务**，做产品前要单独评估）
