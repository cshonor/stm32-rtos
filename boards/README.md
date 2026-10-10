# boards/ —— 板级层

一句话：**换板子只动这里。** `mk/arm-clang.mk` 里不出现任何具体芯片名，
所有的"这颗芯片长什么样"都在这几个 `.mk` 里。

| 文件 | 板子 | 内核 | Flash / SRAM | OpenOCD 配置 |
|---|---|---|---|---|
| `f103rb.mk` | NUCLEO-F103RB（ST 官方 Nucleo-64） | Cortex-M3 | 128K / 20K | `openocd/f103rb.cfg`（板载 ST-Link） |
| `f103c8t6.mk` | Blue Pill / 最小系统板 | Cortex-M3 | 64K / 20K | `openocd/generic-stlink-f103.cfg`（外接 ST-Link） |
| `f407zg.mk` | 正点原子 F407 探索者（STM32F407ZGT6） | Cortex-M4F | 1M / 128K | `openocd/f407zg-stlink.cfg`（外接 ST-Link） |

用法：lab 的 Makefile 里写 `BOARD ?= f103rb`，或命令行覆盖：

```bash
make BOARD=f103c8t6
make BOARD=f407zg flash
tools/newlab.sh labs/05-x --board f103c8t6
```

## 字段

| 变量 | 含义 | 谁在用 |
|---|---|---|
| `BOARD_NAME` | 人类可读的板名 | `make size` 的表头、`flash.sh` / `env.sh` 的打印 |
| `BOARD_DEVICE` | 芯片型号（如 `stm32f103rb`） | 将来接 libopencm3 的 `DEVICE`、CubeMX 对照 |
| `BOARD_CPU` | `cortex-m3` / `cortex-m4` | `-mcpu=`；**决定有没有 FPU、中断现场保护要不要管 s0/s1** |
| `BOARD_TRIPLE` | `armv7m-none-eabi` | `--target=` |
| `BOARD_CFLAGS` | 板子特有的编译开关 | 目前都为空；F407 要用硬浮点就在这里加 `-mfloat-abi=hard -mfpu=fpv4-sp-d16` |
| `BOARD_FLASH_ORIGIN` / `BOARD_FLASH_SIZE` | Flash 起始与容量 | `make flash`（烧 .bin 时要显式给地址）、`tools/newlab.sh` 生成链接脚本 |
| `BOARD_RAM_ORIGIN` / `BOARD_RAM_SIZE` | SRAM 起始与容量 | 同上 |
| `BOARD_LED` | LED 引脚与极性（纯注释性） | `tools/newlab.sh` 的提示、写 `main.c` 时对照 |
| `BOARD_OPENOCD_CFG` | 用哪份 OpenOCD 配置 | `make flash` / `probe` / `openocd` |

> `BOARD_FLASH_ORIGIN` 这个数在三个地方必须一致：
> `boards/<板子>.mk`、lab 的 `linker.ld` 的 `ORIGIN(FLASH)`、OpenOCD 的 flash bank 声明。
> 链接脚本由 `tools/newlab.sh` 从这里的值生成，所以新实验不会漂。

## 加一块新板子

```bash
cp boards/f103rb.mk boards/f103re.mk     # 1. 抄一份最接近的
$EDITOR boards/f103re.mk                 # 2. 改 CPU / 内存 / cfg 路径 / LED
$EDITOR boards/openocd/f103re-stlink.cfg # 3. 写它的 OpenOCD 配置（多数情况改 interface/target 两行）
bash tools/env.sh --board f103re         # 4. 自检确认 cfg 路径找得到
tools/newlab.sh labs/06-x --board f103re # 5. 用它生成一个实验
```

`tools/lib.sh` 的 `boards_list()` 会自动扫出所有 `.mk`，所以新增以后
`env.sh` / `flash.sh` / `newlab.sh` 的报错提示里就会带上这块新板子，不用改脚本。

## OpenOCD 配置的写法

> 配置的唯一真源是本目录。`01-stm32/02-libopencm3/openocd/` 下还有同名两份，
> 那是 2026-09 的首版：`01-stm32/book-notes/` 与 `01-stm32/03-gpio-blink/README.md` 里记录了
> 当时实际敲过的命令，删掉它们那些记录就没法复现了，所以保留作历史副本。
> 新实验一律用 `boards/openocd/`（`BOARD_OPENOCD_CFG` 已指过来）。

两份"形状"，按调试器的来源选：

```tcl
# 形状一：官方开发板，板载调试器（Nucleo / Discovery 这类）
source [find board/st_nucleo_f103rb.cfg]      # 板卡脚本内部已经 source 了 interface + target
reset_config srst_only srst_nogate

# 形状二：自制板 / 核心板，外接一根 USB 转 SWD 的 ST-Link
source [find interface/stlink-v2.cfg]         # 克隆版"小蓝棒"多是 V2
source [find target/stm32f1x.cfg]             # 目标芯片家族
reset_config srst_only srst_nogate
```

三条容易漏的：

1. `reset_config srst_only srst_nogate` —— 少了 `srst_nogate`，gdb 里 `reset` 会失败
   （CPU 已 halt 时不允许拉复位）。
2. xpack 这类"解压即用"的发行版**必须给 `-s <scripts>`**，否则报
   `Can't find interface/…`；brew/apt 装的版本自带搜索路径，不需要。
   `tools/env.sh` 会把这个目录找出来并告诉你。
3. 读保护（RDP）打开过的芯片，OpenOCD 连上但读不出 Flash —— 那要去查芯片是否
   被锁，不是这里的配置问题。
