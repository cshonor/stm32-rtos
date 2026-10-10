# 01-stm32/03-gpio-blink —— 让 PA5 上的 LED 闪起来（NUCLEO-F103RB）

> 对应书：《裸机C编程》第 3 章「嵌入式系统编程」
> （3.3.1 初始化硬件 / 3.3.2 GPIO 引脚编程 / 3.3.3 切换 LED / 3.4 探索构建过程）
> 笔记见 [`book-notes/03-embedded-system-programming/`](../book-notes/03-embedded-system-programming/README.md)
>
> 状态：**✅ 真机实测**（烧录 Verified OK、闪烁被调试器读回证据链完整）

---

## 一、这块板上有什么

| 项 | 值 | 来源 |
|---|---|---|
| 板子 | NUCLEO-F103RB（MB1136） | 板面丝印 |
| MCU | STM32F103RBT6，Cortex-M3 r1p1，128K Flash / 20K RAM | openocd `device id = 0x20036410`（DEV_ID `0x410` = medium-density）+ `flash size = 128 KiB` |
| 用户 LED | **LD2 = PA5**（绿色，低电平点亮？不——**高电平点亮**，见下） | 板面丝印 + 本节实测 |
| 用户按键 | **B1 = PC13** | 板面丝印 + 本节实测（见 §5） |
| 调试器 | 板载 ST-Link/V2-1（`STLINK V2J28M18`，USB `0483:374B`） | openocd |
| 供电 | USB 供电，`Target voltage: 3.239841 V` | openocd |

**LED 的极性**：实测把 PA5 置 1 时 ODR 的 bit5 变 1（`0x0000a020`），
板上 LD2 亮。所以是**高电平点亮**——Nucleo 板的 LED 走 `PA5 → LED → 电阻 → GND`。
（不是所有板子都这样：有些板子是引脚拉低才亮。**这类事只能实测，不能类推。**）

---

## 二、文件

| 文件 | 作用 |
|---|---|
| `main.c` | 教学主程序：开时钟 → 配 PA5 → BSRR 翻转，带 6 个调试观测点 |
| `portprobe.c` | **探针程序**：专测"外设时钟没开时读写寄存器会怎样"，不点灯 |
| `startup.S` | 从 `01-bare-metal` 继承：向量表 + `Reset_Handler`（搬 .data / 清 .bss / 调 main） |
| `linker.ld` | 从 `01-bare-metal` 继承，**Flash 从 64K 改成 128K**（按真实板子，见文件头注释） |
| `Makefile` | 构建 / 烧录 / 只读探测 / 反汇编 / 栈用量 |

---

## 三、寄存器地图（RM0008 §9.2，都是偏移量算出来的）

| 名字 | 地址 | 关键位 | 说明 |
|---|---|---|---|
| `RCC_APB2ENR` | `0x40021018` | bit2 IOPAEN | GPIOA 时钟使能 |
| `GPIOA_CRL` | `0x40010800` | PA5 → bits[23:20] | 低 8 个引脚（PA0–PA7）的配置，每脚 4 位 |
| `GPIOA_CRH` | `0x40010804` | PA8–PA15 | 高 8 个引脚 |
| `GPIOA_IDR` | `0x40010808` | 只读 | 输入数据（读引脚电平） |
| `GPIOA_ODR` | `0x4001080C` | bit5 = PA5 | 输出数据（读能得到当前输出） |
| `GPIOA_BSRR` | `0x40010810` | 低 16 位=置位，高 16 位=复位 | **只写**，读回恒为 0 |
| `GPIOA_BRR` | `0x40010814` | 低 16 位=复位 | BSRR 高 16 位的"专用版" |

引脚配置的 4 位编码（F1 特有，F0/F4 是每脚 2 位的 `MODER`）：

```
[CNF1 CNF0 MODE1 MODE0]
 0 0  x x   通用输出：MODE = 01(10MHz) / 10(2MHz) / 11(50MHz)
 0 1  x x   通用开漏输出
 1 0  x x   复用推挽输出（UART/SPI 用）
 1 1  x x   复用开漏输出
 0 0  0 0   模拟输入（复位默认）
 0 1  0 0   浮空输入
 1 0  0 0   上/下拉输入（上还是下由 ODR 对应位决定）
```

---

## 四、实测：点灯链路

### 4.1 构建与烧录

```console
$ export PATH=/Users/a0000/micromamba/envs/cdev/bin:$PATH
$ make
blink_gpio.elf  :
section                   size        addr
.isr_vector                 96   134217728     ← 0x08000000
.text                      280   134217824     ← 0x08000060
.data                        0   536870912
.bss                        16   536870912
.noinit                      8   536870928
.flash_overflow_check        0   134218104
.ARM.attributes             37           0
blink_gpio.bin = 376 字节

$ make flash
Info : device id = 0x20036410
Info : flash size = 128 KiB
Warn : Adding extra erase range, 0x08000178 .. 0x080003ff
** Programming Finished **
** Verified OK **
** Resetting Target **
```

> `Warn: Adding extra erase range` 不是错：Flash 擦除按页（F1 = 1 KiB）对齐，
> 376 字节的镜像也要占掉一整页 `0x08000000~0x080003FF`。

### 4.2 程序跑起来后，halt 读回（`make probe`）

```console
=== 向量表 @0x08000000 ===
0x08000000: 20005000 08000061 080000b5 080000b5
=== RCC_APB2ENR @0x40021018（应=0x4）===
0x40021018: 00000004
=== GPIOA_CRL / CRH / IDR / ODR / BSRR / BRR ===
0x40010800: 44244444 88844444 0000dffc 0000a020 00000000 00000000
             ↑CRL     ↑CRH     ↑IDR     ↑ODR     ↑BSRR    ↑BRR
=== 观测点变量 @0x20000000 ===
0x20000000: 44244444 0000a020 0000001d 0000a000 00000003 00000004
             crl_after odr_after blink_cnt odr_after boot_stage apb2enr_
             _config   _set                 _reset               readback
pc (/32): 0x08000154
msp (/32): 0x20004ff8
```

逐条读：

| 观测点 | 值 | 结论 |
|---|---|---|
| `RCC_APB2ENR` | `0x00000004` | ✅ 时钟开了（复位值是 `0x00000000`，见 §5） |
| `GPIOA_CRL` | `0x44244444` | ✅ PA5 的 4 位从复位默认 `4` 变成 `2`（`0b0010` = CNF=00 + MODE=10 → 2MHz 推挽输出） |
| `GPIOA_ODR` | `0x0000a020` | ✅ bit5 = 1（此刻 LED 亮）；bit13/15 = 1 是**调试口的上拉**，不是我们写的 |
| `GPIOA_BSRR` | `0x00000000` | ⚠ **BSRR 是只写寄存器**，读回永远是 0（即使刚写完也有内容） |
| `crl_after_config` | `0x44244444` | 与真机读回的 CRL 一致 → 代码里的操作确实生效了 |
| `odr_after_set` | `0x0000a020` | 写 `BSRR = 1<<5` 之后读 ODR，bit5 确实 = 1 |
| `odr_after_reset` | `0x0000a000` | 写 `BSRR = 1<<21` 之后读 ODR，bit5 确实 = 0 |
| `blink_count` | `0x1d` = **29** | 从复位到这一刻，翻转了 29 次 |
| `boot_stage` | `3` | 启动代码 + main 都跑完了（1→2→3） |

**注意 `odr_after_set` 与 `odr_after_reset` 的差**：
`0x0000a020 ^ 0x0000a000 = 0x00000020` —— **只差 bit5**。
这就是"BSRR 只动我关心的那一位，不碰 PA13/PA15 的上拉"的硬证据。

### 4.3 它在动吗？（`resume` 跑 3 秒再 halt）

```console
=== T1: 采样 ===
0x20000008: 00000037        ← blink_count = 55
0x4001080c: 0000a020        ← ODR bit5 = 1（灯亮）
=== 自由跑 3000 ms ===
=== T2: 再采样 ===
0x20000008: 0000003e        ← blink_count = 62
0x4001080c: 0000a000        ← ODR bit5 = 0（灯灭）
```

`62 - 55 = 7` 次翻转 / 约 3.0 秒 → **半周期 ≈ 428 ms，完整闪烁约 1.17 Hz**。

而 `delay(400000)` 里每次迭代在反汇编上是 5 条指令，
按 8 MHz 主频反推：`8e6 × 0.428s ÷ 400000 ≈ 8.6` 周期/次迭代。
**和"每迭代 4 个周期"的直觉差了 2 倍** —— 这就是为什么裸机上的延时不能靠心算（见 §6）。

### 4.4 调试器直接写寄存器（不跑程序也能点灯）

```console
=== T3: 调试器写 BSRR 置位 PA5 ===
> mww 0x40010810 0x20
0x4001080c: 0000a020        ← ODR bit5 立刻 = 1
=== T4: 调试器写 BRR 复位 PA5 ===
> mww 0x40010814 0x20
0x4001080c: 0000a000        ← ODR bit5 立刻 = 0
=== T5: reset run ===
```

**这两步把"寄存器 ↔ 物理现象"直接连起来了**：
`mww` 是调试器通过 SWD 直接往寄存器写一个 32 位数，
中间没有一行 C 代码参与，LED 一样听话。
反过来也成立——**灯不亮时，你可以先怀疑"寄存器写没写进去"，而不是先怀疑代码逻辑**。

### 4.5 书 3.4「探索构建过程」：一条 C 语句 = 几条指令

```console
$ make regs     # llvm-objdump -d blink_gpio.elf | sed -n '/<main>:/,/^$/p'
 80000c4:  movw	r1, #0x1018
 80000ca:  movt	r1, #0x4002        ; r1 = 0x40021018（RCC_APB2ENR）
 80000ce:  ldr	r3, [r1]           ; ┐
 80000d4:  orr	r3, r3, #0x4       ; │ RCC_APB2ENR |= (1u<<2)  → 3 条（读-改-写）
 80000d8:  str	r3, [r1]           ; ┘

 80000ee:  ldr	r1, [r0]           ; ┐
 80000f4:  bic	r1, r1, #0xf00000  ; │ GPIOA_CRL &= ~(0xF<<20) → 3 条
 80000f8:  str	r1, [r0]           ; ┘
 80000fa:  ldr	r3, [r0]           ; ┐
 8000100:  orr	r3, r3, #0x200000  ; │ GPIOA_CRL |= (0x2<<20)  → 3 条
 8000104:  str	r3, [r0]           ; ┘
                                     ; 合计：配置 PA5 = 6 条指令、2 次 ldr + 2 次 str

 8000138:  str.w	r12, [r0, #0x10]   ; ★ GPIOA_BSRR = (1<<5) → 只有 1 条 str！
 800013c:  ldr	r5, [r0, #0xc]     ; odr_after_set = GPIOA_ODR
 8000142:  ldr	r5, [r2]           ; ┐
 8000144:  adds	r5, #0x1           ; │ blink_count++
 8000146:  str	r5, [r2]           ; ┘
```

延时循环（`delay` 被 `-Os` 内联进了 main）：

```console
 800014c:  ldr	r5, [sp]           ; ← 每次都从栈上重新读 n（因为参数是 volatile！）
 800014e:  subs	r6, r5, #0x1
 8000150:  str	r6, [sp]           ; ← 写回
 8000152:  cbz	r5, 0x8000158
 8000154:  nop
 8000156:  b	0x800014c           ; 5 条指令的循环
```

> **`volatile` 参数让循环多出 `ldr`/`str` 各一条**：编译器不被允许把 `n` 留在寄存器里，
> 每次迭代都必须"真的访问内存"。这正是 `volatile` 的定义（ch04/ch05 详述），
> 代价就是慢一点 —— 但换来的是"这个循环不会被优化掉"。

---

## 五、实测：外设时钟这个坑（`portprobe.c`）

问一个所有教程都说"必须先开时钟"、但很少说清"不开会怎样"的问题。
程序只在开头开了 GPIOA 时钟，然后在**没开 GPIOC 时钟**的前提下读它、写它。

```console
$ make probe-ports    # 烧探针程序
$ make read-ports     # 读回
0x20000000: 44444444 00000000 44484444 00000000 44444444 00000000 0000fffe 44484444
0x20000020: 44444444 44444444 00000004 00000000 0000000d 60502003
```

| # | 变量 | 读到的 | 何时读 | 结论 |
|---|---|---|---|---|
| 1 | `c_crl_off` | `0x44444444` | 时钟**关**时读 `GPIOC_CRL` | **能读到复位值**（不是 0，也没报错） |
| 2 | `c_idr_off` | `0x00000000` | 时钟**关**时读 `GPIOC_IDR` | **读不到真实电平，是 0** |
| 3 | `b_crl_off` | `0x44484444` | 时钟关时读 `GPIOB_CRL` | 同上，且注意 PB3 位 = `8`（见下） |
| 4 | `c_odr_echo` | `0x00000000` | 时钟关时**写** `ODR=0xA5A5A5A5`，立刻读回 | **写丢失**（读回 0，不是 0xA5A5A5A5） |
| 5 | `c_crl_on` | `0x44444444` | 开时钟后读 | 与 #1 相同 → 说明 #1 读到的确实是寄存器内容 |
| 6 | `c_odr_on` | `0x00000000` | 开时钟后读 `ODR` | **那个 0xA5A5A5A5 确实没写进去**（不是"暂时读不到"） |
| 7 | `c_idr_on` | `0x0000fffe` | 开时钟后读 `GPIOC_IDR` | **PC13 = 1** → 按键松手态是 1 |
| 8 | `b_crl_on` | `0x44484444` | 开时钟后读 | 同上，PB3 = `8` |
| 9 | `d_crl` | `0x44444444` | GPIOD（全程没人碰） | **GPIO 复位默认值 = 0x44444444**（每脚 `0b0100` = 浮空输入） |
| 10 | `d_crh` | `0x44444444` | 同上 | CRH 也是 |
| 11 | `d_idr` | `0x00000004` | 同上 | PD2 读回 1 —— **悬空引脚的读数是随机的，别信** |
| 12 | `d_odr` | `0x00000000` | 同上 | 输出数据寄存器复位为 0（但 GPIOD 没配成输出，无所谓） |
| 13 | `stage` | `0x0000000d` = **13** | 程序自己写的 | ✅ **13 步全部执行完，没有 HardFault** |

### 5.1 三条结论（都能反着坑人）

**① "不开时钟写寄存器" = 静默丢失，不报错、不 HardFault。**
`stage = 13` 证明全程跑完，没有任何异常。
`c_odr_echo = 0` 且 `c_odr_on = 0` 证明那个 `0xA5A5A5A5` **根本没进寄存器**。
→ 这就是"灯不亮，代码看起来完全正确"的第一号成因。

**② "不开时钟读寄存器"：配置类寄存器能读到复位值，状态类寄存器读到 0。**
`CRL` 读出 `0x44444444`（复位值），`IDR` 读出 `0`（读不到引脚）。
→ 机制上可以理解为：寄存器单元的**存储内容**在时钟关闭时仍可被读出，
但 `IDR` 的值来自**引脚采样逻辑**，采样需要时钟，所以是 0。
（机制是推断，**行为是实测的**。别把推断当手册用。）

> ⚠ 这条在别的 STM32 系列上**不一定成立**。F4/L4 等系列对未使能时钟的外设访问
> 会产生总线错误（BusFault）。判断方法永远是实测 + 查该系列的参考手册，
> 而不是把 F1 的行为外推。

**③ `0x44444444` 不是"铁板一块"的复位值，例外都在调试口。**
实测三处例外：

| 端口 | 实测复位值 | 例外引脚 | 值 | 为什么 |
|---|---|---|---|---|
| GPIOA_CRL | `0x44444444` | —— | —— | 标准 |
| GPIOA_CRH | **`0x88844444`** | PA13 / PA14 / PA15 | `8` = `0b1000` = 上/下拉输入 | **SWDIO / SWCLK / JTDI**，调试口默认带上拉 |
| GPIOB_CRL | **`0x44484444`** | PB3 | `8` | **JTDO / TRACESWO**，同理 |
| GPIOC_CRL | `0x44444444` | —— | —— | —— |
| GPIOD_CRL | `0x44444444` | —— | —— | —— |

这也解释了 §4.2 里 `GPIOA_ODR = 0x0000a020` 为什么会**莫名其妙多出 bit13/15** ——
不是我们的程序写的，是调试口的上拉在 `ODR` 里的体现。

**所以 `GPIOA_ODR = 0x20;`（直接赋值）这个写法比想象的更危险**：
它会顺手把 PA13/PA15 的上拉写掉。用 `BSRR` 就没有这个问题。

### 5.2 板载按键 B1（PC13）的松手态

| 观测 | 值 | 说明 |
|---|---|---|
| `GPIOC_CRL` 复位值 | `0x44444444` | PC13 的 4 位 = `4` = `0b0100` = **浮空输入**（没有内部上下拉） |
| `GPIOC_IDR` bit13，松手 | **1** | 有上拉在起作用 —— 但这个上拉**不在 MCU 内部**（CRL 说明是浮空输入） |

→ 结论：**松手读 1**；**按下应该读 0**（按键把 PC13 拉到 GND）。
上拉的来源需要对照 NUCLEO-F103RB 原理图（MB1136）才能确定，
本节只报"实测读数"，不猜电路。

**按下态怎么自己验证**：跑 `portprobe` 后，
按住板上的蓝色 B1 按键不放，在另一个终端执行 `make read-ports`，
看 `c_idr_on` 的 bit13 是否从 1 变 0。

---

## 六、坑点汇总

| 常识 / 书上怎么说 | 实测是什么 |
|---|---|
| "点灯就是配好 GPIO 然后写数据寄存器" | **必须先开 `RCC_APB2ENR`**。不开时钟的写会静默丢失（§5 #4/#6），不报错、不警告 |
| "复位后寄存器都是 0" | GPIO 的 CRL/CRH 复位值是 `0x44444444`（浮空输入），**不是 0**；且 PA13/14/15、PB3 是例外（`0x8`） |
| "`GPIOA_ODR = 0x20` 就能点亮 PA5" | 能点亮，但会**顺手抹掉 PA13/PA15 的上拉位**（实测 ODR 复位后不是 0，是 `0x0000a000`）。改单个引脚用 `BSRR` |
| "改寄存器用 `=` 赋值最直接" | 一个 `CRL` 管 8 个引脚，`=` 赋值会把其余 7 个引脚的配置一起改成 0000。必须 `&= ~` 再 `\|=`（实测 6 条指令） |
| "`BSRR` 读回来能看到刚才写的值" | **BSRR/BRR 是只写寄存器，读回恒为 0**（实测 `0x40010810: 00000000`）。想看输出状态要读 `ODR` |
| "延时循环 `for(i=0;i<n;i++);` 能精确控时" | 实测 `delay(400000)` 得到约 428 ms 半周期 → **每次迭代约 8.6 个周期**，是"4 周期"直觉的 2 倍多。而且优化级别一变就全变 |
| "`volatile` 只是保险，加了没坏处" | 它会让循环多出 `ldr`/`str`（实测 `delay` 里 `n` 每次迭代都从栈上重读），**慢，但保证循环不会被优化掉**。要不要加是权衡 |
| "链接脚本里 Flash 写 64K 也行" | 写小不致命（超了才报错），但会让人误判板子型号。实测板子是 **128 KiB**（`device id 0x20036410` + `flash size = 128 KiB`） |
| "烧 376 字节就占 376 字节" | 擦除按页（1 KiB）对齐。实测 `Warn: Adding extra erase range, 0x08000178 .. 0x080003ff` |
| "编译出来的 `.bin` 就是程序的全部" | `.bss`/`.noinit` 是 `NOBITS`，**不占 Flash**（所以 96+280+0+16+8 的段加总 ≠ 376）。它们的空间是 RAM，内容是启动代码造的 |

---

## 七、命令速查

```console
export PATH=/Users/a0000/micromamba/envs/cdev/bin:$PATH

make                 # 构建 + 段大小
make flash           # 烧录主程序（闪灯）
make probe           # ★ halt 后读回向量表 / RCC / GPIOA / 观测点变量
make regs            # main 的反汇编（看每条 C 语句几条指令）
make dis             # 整个 .text 的反汇编
make symbols         # 符号表
make check-stack     # 生成 .su 栈用量（裸机没有守卫页，栈爆了不报错）

make probe-ports     # 烧探针程序（测"时钟没开"的行为，会覆盖主程序）
make read-ports      # 读探针结果
# 测完记得 make flash 把主程序烧回去
```

gdb 源码级调试（书 3.6 / 3.7）需要开两个终端：

```console
# 终端 A
~/.local/xpack-openocd-0.12.0-7/bin/openocd -f ../02-libopencm3/openocd/f103rb.cfg

# 终端 B
~/.local/arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi/bin/arm-none-eabi-gdb blink_gpio.elf
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) break main
(gdb) continue
(gdb) next                    # 单步：跳过函数
(gdb) step                    # 单步：进入函数
(gdb) info registers
(gdb) x/6xw 0x40010800        # 看 GPIOA 的 CRL/CRH/IDR/ODR/BSRR/BRR
(gdb) p/x crl_after_config    # 直接看 C 变量
(gdb) monitor reset run
```
