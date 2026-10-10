# 工具台（toolbench）

> 书 1.2 让装的是 **System Workbench for STM32**（SW4STM32，已停止维护）。
> 那个"工作台"解决的是同一个问题：**把编译器、构建系统、烧录器、调试器四件事
> 打包成一个验证过的组合**。本目录是它的命令行等价物——但把"打包"换成"可查看"：
> 每一步命令都看得见，出错能定位到具体环节。
>
> 这不是又一套 IDE 配置。它只做一件事：**让每个 lab 的目录里只剩这个实验自己的东西。**

## 一、没有工具台之前是什么样

| 症状 | 具体表现 |
|---|---|
| 规则重复 | `01-stm32/00`、`01`、`03`、`labs/*` 各抄一份 CFLAGS / LDFLAGS / `%.o: %.c`，改一个编译选项要改五处 |
| 路径硬编码 | `$(HOME)/.local/xpack-openocd-0.12.0-7/bin/openocd`、`/Users/a0000/micromamba/envs/cdev/bin` 写死在 Makefile 和笔记正文里，换台机器就找不到 |
| 环境靠记 | "这台机器上 clang 在哪、openocd 的 scripts 目录在哪"只存在于上一轮的对话记录里 |
| 新实验靠拷 | 开一个新实验 = 从旧目录拷 Makefile 再手改板子相关的数字（Flash 容量、LED 引脚） |

## 二、三层结构

```
tools/    脚本层：环境自检、烧录、调试、生成新实验室     ← 面向"人"
mk/       构建层：一份共享的 CFLAGS/LDFLAGS/规则        ← 面向 make
boards/   板级层：CPU、内存布局、OpenOCD 配置、LED 引脚  ← 面向"芯片"
```

三层的分工只有一条原则：**换板子只动 `boards/`，改编译选项只动 `mk/`，
换机器只跑 `tools/env.sh`。** 三者互不牵连。

```
boards/f103rb.mk ──┐
boards/f103c8t6.mk ├─→ mk/arm-clang.mk ──→ 各 lab 的 Makefile（4 行）
boards/f407zg.mk ──┘        ↑
                            │
                    mk/locate-tools.mk（工具在哪）
                            ↑
                    tools/env.sh（探测 + 自检 + 注入 PATH）
```

## 三、快速开始

```bash
# 1. 这台机器现在能不能做嵌入式？（会真的编译/链接/转换一遍）
bash tools/env.sh

# 2. 工具不在 PATH 上时（macOS 的 micromamba、xpack openocd 都属于这种）
source tools/env.sh --export

# 3. 编译一个 lab
cd labs/01-hello && make

# 4. 插上板子，烧录
make flash

# 5. 源码级调试（自动起 openocd + gdb，退出时收摊）
../../tools/dbg.sh hello.elf
```

## 四、`tools/` 脚本

### `tools/env.sh` —— 分层自检

把 `01-stm32/book-notes/01-hello-world/1.2` 里那张"分层确认表"变成可执行脚本。
**每一层都真跑一次**（不是 `command -v` 挨个问），哪一层没过，问题就在那一层。

| 层 | 检查什么 | 缺了会怎样 |
|---|---|---|
| — | 工具台自身完整性（mk/ boards/ tools/ 是否齐） | 说明仓库没 clone 全 |
| 1 | `make` | 构建驱动器，缺了只能手敲三行命令 |
| 2 | `clang`（真编一个 armv7m 目标文件，读 ELF machine） | 什么都做不了 |
| 3 | `ld.lld`（真链接一次，读入口地址） | 编不了可执行文件 |
| 4 | `llvm-objcopy`（真抽一次 .bin） | 烧录器要的 .bin 出不来 |
| 5 | `python3` | 主机侧断言（`make vectors`）跑不了，编译不受影响 |
| 6 | `openocd` + 板级 cfg 是否存在 | 只能编译，不能烧录/调试 |
| 7 | `arm-none-eabi-gdb` | 能烧录，没有源码级单步 |
| 8 | **真连一次板子**（`--hw` 才跑） | 按 USB / SWD / 内核 / Flash 四层报日志 |

选项：`--board <板子>`（影响 `-mcpu` 与用哪份 OpenOCD 配置）、`--hw`、`--export`。

退出码：`0` = 编译链完整可用；`1` = 有硬伤。所以也能直接塞进 CI 当门禁。

自动翻的候选位置（跨平台）：micromamba/conda 的 `cdev` 环境、`/opt/homebrew`、
`~/.local` 下的 xpack 与 Arm GNU 官方包、Windows 的 `Program Files`、
`AppData/Local/Programs`、winget / chocolatey / scoop 的落地目录。

### `tools/flash.sh` —— 烧录

```bash
tools/flash.sh labs/01-hello/hello.bin                  # 默认板子 f103rb
tools/flash.sh nothing/out.elf --board f103c8t6         # 指定板子
tools/flash.sh out.bin --no-verify                      # 跳过逐字节校验
```

替你决定"要不要给 Flash 起始地址"：`.elf` 不用（openocd 自己解析 program header），
`.bin` 必须给（纯字节流没有地址信息，这里从 `boards/<板子>.mk` 取）。

> ⚠ 命令末尾的 `exit` 不能省。少了它 openocd 会一直挂着不退
> （`01-stm32/03-gpio-blink` 里记着这次教训：实测第一次两分钟没退出，只能 pkill）。

### `tools/dbg.sh` —— 一条命令起 openocd + gdb

```bash
tools/dbg.sh labs/01-hello/hello.elf            # 在 Reset_Handler 停下
tools/dbg.sh hello.elf --break main             # 换断点
tools/dbg.sh --attach                           # 复用已在跑的 openocd
tools/dbg.sh hello.elf --batch -ex "info registers"
```

书里点一下 Debug 按钮，背后是三个进程（`01-stm32/book-notes/02-ide/2.1` Q1）。
这个脚本拉起前两个：先起 OpenOCD，**等 `:3333` 真的可连**（不是固定 sleep——
ST-Link 枚举快慢跟 USB 口有关），再起 gdb；gdb 退出后自动收摊。
`:3333` 上已经有别人的 openocd 时直接复用，且退出时不会把它的杀掉。

### `tools/newlab.sh` —— 生成新实验室

```bash
tools/newlab.sh labs/02-uart                     # 默认板子 f103rb
tools/newlab.sh 01-stm32/04-uart --board f103c8t6
tools/newlab.sh labs/03-x --target probe_uart    # 产物名与目录名不同
```

从 `tools/templates/bare-metal/` 拷一份，按板子把链接脚本的内存布局、
Makefile 的 `BOARD`、README 的标题全部填好。生成完 `make` 就能出 `.bin`。

生成之后要自己改的两处（脚本不猜）：

1. `main.c` 顶部的 `LED_BASE` / `LED_PIN` / `LED_ACTIVE_LOW`——模板注释里给了
   NUCLEO-F103RB（PA5 高电平）、Blue Pill（PC13 低电平）、F407（PF9 低电平）三组取值；
2. `README.md` 的"这个实验要回答什么"——一句话写清要验证的机制。

## 五、`mk/` 构建层

### lab 的 Makefile 长什么样

```make
BOARD  ?= f103rb
TARGET := blink
SRCS   := startup.S main.c
include ../../mk/arm-clang.mk
```

四行。之后自动获得：

| 目标 | 做什么 |
|---|---|
| `make` | 编译 + 链接 + objcopy + 体积账单（段明细、.bin 字节数、与 Flash 容量的比例） |
| `make flash` | 编程 + 校验 + 复位 + 退出 |
| `make probe` | halt 后只读回读（默认向量表 + pc/msp；各 lab 用 `PROBE_EXTRA` 追加自己的观测点） |
| `make openocd` / `make gdb` | 前台常驻 `:3333` / 连上去在 `GDB_BREAK`（默认 `Reset_Handler`）停下 |
| `make dump` / `sections` / `symbols` / `size` | 反汇编 / 段表 / 符号表 / 体积 |
| `make clean` | 清 `*.o *.elf *.bin *.hex *.map *.su` |

### 可覆盖的变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `BOARD` | 无（必填） | `boards/` 下的文件名 |
| `TARGET` | 当前目录名 | 产物名 |
| `SRCS` | `*.c *.S` | `.S` 走 ASFLAGS，`.c` 走 CFLAGS |
| `OPT` | `-Os` | 优化级别 |
| `PROBE_EXTRA` | 空 | 追加到 `make probe` 的 openocd `-c` 命令 |
| `GDB_BREAK` | `Reset_Handler` | `make gdb` 的断点 |
| `CFLAGS` / `ASFLAGS` / `LDFLAGS` | 见文件 | 在 include 之前 `+=` 可追加 |
| `LLVM_BIN` / `GCC_ARM_BIN` / `OPENOCD` / `OPENOCD_SCRIPTS` | 从 PATH | 见 `mk/locate-tools.mk` |

**为什么 make 里不做路径搜索**：`$(shell)` 在 Windows 原生 make（`SHELL=cmd`）上
不可靠，会出现"Mac 上好好的、Windows 上静默拿到空字符串"——这类错最难查。
所以契约是：**PATH 里有什么就用什么**，搜索的活交给 `tools/env.sh`（那里有 shell）。

## 六、把老 lab 迁过来

以 `01-stm32/03-gpio-blink` 为例，改动只有三处：

1. 删掉 `CC/LD/OBJCOPY/…`、`CFLAGS/ASFLAGS/LDFLAGS`、`%.o`/`%.elf`/`%.bin` 规则——全在 `mk/arm-clang.mk`；
2. 开头写 `BOARD / TARGET / SRCS` + `include ../../mk/arm-clang.mk`；
3. 本目录特有的目标（`portprobe`、`regs`、`check-stack`）保留在 include **之后**；
   特有的 `probe` 观测点写成 `PROBE_EXTRA`，不必另写一条 probe 规则。

已迁：`labs/01-hello`（完整示范）、`01-stm32/03-gpio-blink`（含特有目标）。
轻改（只把硬编码路径改成三级回退，结构不动）：`01-stm32/01-bare-metal`、`01-stm32/02-libopencm3`。
`01-stm32/01-bare-metal` 刻意保留自己的规则——它同时构建汇编版和 C 版两个变体，
不属于"一个 TARGET 一份产物"的形态，硬套共享层反而更难读。

## 七、跨平台

| 事 | macOS | Windows（Git Bash / MSYS2） | Linux |
|---|---|---|---|
| 编译器 | `brew install llvm`，或 micromamba `cdev` | `winget install LLVM.LLVM` | `apt install clang lld` |
| make | 预装（GNU make 可能叫 `gmake`） | `winget install ezwinports.make` | 预装 |
| OpenOCD | `brew install openocd`，或 xpack darwin-arm64 解压 | winget / xpack | `apt install openocd` |
| ST-Link 驱动 | **免驱**（HID） | 要装 ST-Link 驱动 | 要装 udev 规则 |
| gdb | Arm GNU Toolchain 官方包 | Arm GNU Toolchain for Windows | `apt install gdb-arm-none-eabi` |
| 易踩 | `/usr/bin/ld` 是 Mach-O 链接器，报 `unknown option: -T` | make 常常是唯一缺的那件；`llvm-readelf` 不在官方包里（退到 `llvm-readobj`） | — |

`tools/env.sh` 对这三条路径都做了候选位置探测，并对上述"易踩"给出对应的修复提示。

## 八、和笔记的对应

| 笔记 | 工具台里对应的东西 |
|---|---|
| `01-hello-world/1.2` 分层确认表 | `tools/env.sh` 的 8 层 |
| `02-ide/2.2` 三条链路（构建/烧录/调试） | `mk/arm-clang.mk` 的 `all` / `flash` / `openocd`+`gdb` |
| `02-ide/2.2` "烧 .bin，调 .elf" | `flash.sh` 对两种格式的分支 |
| `11-linker` 内存地图 | `boards/<板子>.mk` 的 `BOARD_FLASH_*` / `BOARD_RAM_*` |
| `19-systick-and-timer` 精确延时 | 模板里 `delay()` 的注释（粗略延时，精确计时等 SysTick） |
