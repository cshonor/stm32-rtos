# 00-toolchain-clang —— 不用 GCC，把 C 变成能烧进 Flash 的字节

本目录回答一个问题：**在没有操作系统、也没有 arm-none-eabi-gcc 的机器上，
C 语言是怎么变成一段能操作 STM32 寄存器的机器码的？**

结论先放这儿：**C 语言不需要 GCC**。GCC 只是符合 C 标准的一种实现，
Clang 是另一种；真正不可替代的是**标准**和**器件手册**，不是某家厂商的编译器。

- 编译器：clang 23.1.0（LLVM 自带 arm 后端）
- 链接器：ld.lld 23.1.0（GNU 兼容风味，直接吃 GNU 链接脚本）
- 二进制工具：llvm-objcopy / objdump / readelf / size / nm
- 全程 `-nostdlib`：不链 libc、不链 crt0、不链任何启动文件

所有命令在 macOS 26.6.2 (arm64) + micromamba `cdev` 环境实测通过。

## 文件

```
startup.c      向量表 + Reset_Handler（crt0 的活自己干）+ __aeabi_* 兜底
main.c         MMIO 直接写寄存器点 PC13；两个 volatile 正反面教材
linker.ld      Flash 64K @0x08000000 / SRAM 20K @0x20000000 的物理地图
libc-trap.c    探针：哪些"无害"的 C 写法会偷偷拉进外部依赖
Makefile       clang + ld.lld 全流程，含 3 个自检目标
blink.elf/.bin 产物（.gitignore 已忽略）
```

## 构建

```bash
export PATH=/Users/a0000/micromamba/envs/cdev/bin:$PATH
cd 01-stm32/00-toolchain-clang
make                # 编译 + 链接 + objcopy + size
make dump           # 反汇编
make sections       # 段表 + 程序头
make check-libc     # 看编译器替 C 代码生成了哪些外部符号
make check-eabi     # 验证 __aeabi_* 是否被 startup.c 接住
```

### 实测输出

```
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -fno-builtin \
      -fno-common -Wall -Wextra -Os -g -ffunction-sections -fdata-sections \
      -fno-unwind-tables -fno-asynchronous-unwind-tables -c startup.c -o startup.o
clang ... -c main.c -o main.o
ld.lld -T linker.ld --entry=Reset_Handler --gc-sections -Map=blink.map -o blink.elf startup.o main.o
llvm-objcopy -O binary blink.elf blink.bin
```

段落在哪（`llvm-size -A blink.elf`，134217728 = 0x08000000，536870912 = 0x20000000）：

```
section                   size        addr
.text                      292   134217728     ← 代码 + 向量表，住 Flash
.data                        4   536870912     ← 有初值的全局，运行地址在 RAM
.bss                         4   536870916     ← 无初值的全局，运行地址在 RAM
.flash_overflow_check        0   134218024     ← 链接期自检哨兵
```

关键符号（`llvm-nm -n blink.elf`）：

```
08000040 T Reset_Handler
0800009c T main
08000124 A _sidata        ← .data 的初值躺在 Flash 的这个地址
20000000 D _sdata         ← .data 的运行地址（RAM）
20000000 D g_has_init     ← volatile u32 g_has_init = 0xA5A5A5A5u;
20000004 D _edata
20000004 B _sbss
20000004 B g_tick         ← volatile u32 g_tick;（不占 Flash）
20000008 B _ebss
20005000 A _estack        ← 0x20000000 + 20K，栈顶
```

`.bin` 296 字节 = .text 292 + .data 4。**Flash 里没有 .bss 的位置**——
它靠启动代码清零，不是靠初值。

## 笔记落点（原"三个实测发现"和 include 清单已并入 book-notes）

本 lab 的三个实测发现已按主题并入 `book-notes/00-mental-model/`，此处只留索引：

| 实测发现 | 笔记落点 |
|---|---|
| 丢掉 volatile 的轮询会被搬出循环（`wait_press_bad/good` 反汇编对比） | [00.2 手段 2](../book-notes/00-mental-model/00.2-操作硬件的三个手段.md) |
| 没人搬 .data，初值就是 RAM 垃圾（`Reset_Handler` 16 条指令） | [00.1 三、四](../book-notes/00-mental-model/00.1-没有OS的C语言.md) |
| 编译器在背后调 `__aeabi_*`（`make check-libc` / `check-eabi`） | [00.1 二](../book-notes/00-mental-model/00.1-没有OS的C语言.md) |
| freestanding 下能 include 什么（clang 23.1.0 逐个实测） | [00.3 二·补](../book-notes/00-mental-model/00.3-没有GCC行不行.md) |

补充一句 lab 侧的做法：本目录的 `main.c` **一个头文件都不 include**，
`u32`/`u8` 自己 `typedef`——这是「完全不依赖工具链给什么」的最保守写法。

## 坑点清单（真机踩过，按命中顺序）

| # | 现象 | 原因 / 解法 |
|---|---|---|
| 1 | `ld: unknown option: -T` | macOS 的 `/usr/bin/ld` 是 Mach-O 链接器。必须显式用 `ld.lld` |
| 2 | `make` 里 `LD ?= ld.lld` 不生效 | make 内建变量 `LD` 默认就是 `ld`，`?=` 覆盖不了，要用 `:=` |
| 3 | 全局变量只写不读 → `.data`/`.bss` 尺寸为 0 | `-Os` 把它优化掉，`--gc-sections` 顺手丢段。加 `volatile` |
| 4 | `__attribute__((used))` 的函数没进最终镜像 | `used` 只约束编译器；链接器 `--gc-sections` 从 entry 做可达性分析，没人调就丢 |
| 5 | 镜像里莫名多出 `.ARM.exidx` | `-fno-unwind-tables` 去不掉（实测），链接脚本没写它也会被 LLVM 塞进 Flash → `/DISCARD/` 丢掉 |
| 6 | 只实现 `memcpy` 仍报 undefined | 编译器生成的是 `__aeabi_memcpy`；且 `__aeabi_memset(dst, n, c)` 的**参数顺序与 `memset(dst, c, n)` 相反** |
| 7 | 自写 `while` 循环清零后仍被怀疑会变 `memset` | 实测 clang 23 + `-Os` 下没触发；结构体赋值则会。`-fno-builtin` 只挡一部分 |

## 还没做的（等板子）

- 真机烧录：`openocd -f interface/stlink.cfg -f target/stm32f1x.cfg` + `program blink.elf verify reset exit`
  或用 `llvm-objcopy` 出 .hex/.bin 后走 ST-Link Utility
- PC13 是 Blue Pill 的板载 LED，且**低电平点亮**，所以代码里 `BSRR = 1<<13` 是灭、`1<<(13+16)` 是亮
- 时钟树没配，跑的是复位后的 HSI 8MHz；真正的延时计数要等 01-stm32/06 用 SysTick 校准
