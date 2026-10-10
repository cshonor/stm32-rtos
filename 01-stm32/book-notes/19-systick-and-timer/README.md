# 第 19 章（补充篇）SysTick 与定时器 —— 章节导航

> 书：**⚠ 本书 18 章里没有这一章**——这是书外补充，因为"时间"是裸机的刚需
> （去抖、延时、超时、调度全靠它），而书里完全没有讲
> 对应实验：`01-stm32/06-timer`（⬜ 待建）
> 本篇数据：**全部为本次实测**（clang 23.1.0 / macOS arm64 / armv7m 交叉 / `ld.lld` 真实链接）
> + 少量**算式推导**与**引自 RM0008** 的内容（已在各篇内逐条标注）

## 这一章在讲什么

前 18 章里，程序只有两种时间观：**没有时间**（写完就跑完）和**忙等**（`for` 循环）。
但真实需求全都要时间：

| 需求 | 需要什么 |
|---|---|
| 按键去抖 | "按下后 20 ms 再看一次" |
| LED 闪烁 | "每 500 ms 翻转一次" |
| 串口超时 | "3 个字符时间内没收到就认为一帧结束" |
| 传感器采样 | "每 10 ms 读一次" |
| RTOS 心跳 | "每 1 ms 做一次调度检查"（ch20） |

**裸机上没有操作系统给你 `sleep()`，时间是自己造出来的。**

一句话概括全章：

> **用 SysTick 造一个 1 ms 心跳，把"等一段时间"改写成"问到点了吗"，
> 而"问"这句必须用回绕安全的写法——这是裸机时间的全部核心。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 19.01 | SysTick 是内核自带的心跳 | [19.01-SysTick是内核自带的心跳](19.01-SysTick是内核自带的心跳.md) |
| 19.02 | 配置成 1 ms 心跳 | [19.02-配置成1ms心跳](19.02-配置成1ms心跳.md) |
| 19.03 | g_ms 与回绕安全的时间比较 | [19.03-g_ms与回绕安全的时间比较](19.03-g_ms与回绕安全的时间比较.md) |
| 19.04 | 三种等待的对比 | [19.04-三种等待的对比](19.04-三种等待的对比.md) |
| 19.05 | 通用定时器 TIM2/TIM3 | [19.05-通用定时器TIM2TIM3](19.05-通用定时器TIM2TIM3.md) |
| 19.06 | 时间相关的三个经典 Bug | [19.06-时间相关的三个经典Bug](19.06-时间相关的三个经典Bug.md) |
| 19.07 | 与 PC 和 LDD- 侧对照与最小可跑 | [19.07-与PC和LDD-侧对照与最小可跑](19.07-与PC和LDD-侧对照与最小可跑.md) |

> 说明：本篇**无原书页码**——书里根本没有这一章。小节划分来自旧章笔记 `ch19-systick-and-timer.md`
> 的一级结构（一 ~ 六），按"SysTick → 用法 → 对比 → 定时器 → Bug → 对照"重排为 19.01–19.07。

## 与书的差异（重要）

| 维度 | 书 | 我 |
|---|---|---|
| 时间 | **完全没讲**（18 章里没有 SysTick 这一章） | 补了整篇，7 个小节，**全部实测**（交叉编译 + 真实链接 + 主机模拟） |
| 延时 | ch05 用忙等 | ⭐ 实测：**非 volatile 忙等在 `-Os` 下只剩一条 `bx lr`**（延时直接变 0）；正确方案只多 **8 字节** |
| 时基 | 书用 NUCLEO-F030R8（Cortex-M0） | 本仓库 NUCLEO-F103RB（Cortex-M3）+ clang/ld.lld，**所有数字重新测过** |
| 定时器 | 没讲 | ⭐ 实测 TIM2 配置 = **64 B**，比 SysTick 版（36 B）贵一倍的 28 B **就是开 `RCC_APB1ENR` 那一行** |

## 核心实测数据（本篇的锚点）

```
① ⭐⭐ 最重要的发现：向量表里不写 ISR，它会被 --gc-sections 整个删掉
$ ld.lld -T linker.ld --gc-sections -o vt16.elf vec16.o app_tick2.o   # 向量表 16 项
   text 124 / data 8 = 132 B    08000040 00000010 T SysTick_Handler   ← ✅ 在
$ ld.lld -T linker.ld --gc-sections -o vt2.elf  vec2.o  app_tick2.o   # 向量表 2 项
   text  52 / data 8 =  60 B    （符号表里没有 SysTick_Handler）       ← ❌ 没了
⚠ 链接不报错、size 还变小，只有上电 SysTick 第一次触发才 HardFault
差值 124-52 = 72 B = 向量表扩容 56 B + ISR 本体 16 B

② ⭐ 回绕安全判据零成本（vt16.elf 反汇编）
 8000064: ldr  r3, [r0]        ← now = g_ms
 8000066: subs r3, r3, r2      ← now - next
 8000068: bmi  0x8000064       ← 负数就回跳
→ 就是 subs + bmi 两条指令，和普通无符号比较同价

③ ⭐ 两种写法在回绕点的分歧（wrap.c 实测输出）
  next=4294967280 now=4294967280  now>=next:1  (int32)(now-next)>=0:1  差值=0 ms
  next=4294967280 now=0           now>=next:0  (int32)(now-next)>=0:1  差值=16 ms  ← ⚠
  next=4294967280 now=16          now>=next:0  (int32)(now-next)>=0:1  差值=32 ms  ← ⚠
  ⚠ 朴素写法从此永远不触发

④ ⭐ 回绕时间换算（实测打印）
  uint32_t 毫秒 = 49.7 天    uint32_t 微秒 = 71.58 分钟
  uint64_t 纳秒 = 584.5 年   (int32_t) 安全跨度 = 24.86 天

⑤ ⭐ SysTick 重载值（实测）
  CPU= 8 MHz → RVR = 7999     CPU=72 MHz → RVR = 71999
  ⚠ 写成 hz/1000（不减 1）慢 1/1000；不减 1 累积一天约多走 10.8 秒

⑥ ⭐ 四种等待在各 -O 下的存活（Cortex-M3，指令条数）
  函数           -O0  -O1  -O2  -Os   -Os 下变成什么
  wait_bad        18    2    2    1   bx lr        ← 整个没了
  wait_vol        18   14   29   12   循环保住
  wait_flag        8    8    1    1   bx lr        ← 空转等标志也没了
  wait_flag_v      8    6   16    6   循环保住

⑦ ⭐ 裸机尺寸对比（ld.lld --gc-sections 真实链接）
  SysTick 配置版  text 36 / data 0 = 36 B      ← 3 条 str，常量折叠成 7999
  忙等版          text 48 / data 4 = 52 B
  SysTick 心跳版  text 52 / data 8 = 60 B      ← 正确方案只比忙等多 8 B
  TIM2 配置版     text 64 / data 0 = 64 B      ← 比 SysTick 贵 28 B（开 RCC 时钟）
  向量表 16 项版  text124 / data 8 = 132 B

⑧ ⭐ SysTick_Handler 本体（16 B / 6 条指令）
  movw r0,#0x0 ; movt r0,#0x2000 ; ldr r1,[r0] ; adds r1,#0x1 ; str r1,[r0] ; bx lr

⑨ ⭐ 64 位毫秒不是原子的（atomic.c -Os 反汇编）
  read32（4 条）: ldr  r0,[r0]                        ← 原子
  read64（4 条）: ldm  r0,{r0,r1}
  tick32（6 条）: ldr r1,[r0] ; adds r1,#1 ; str r1,[r0]
  tick64（7 条）: ldrd r1,r2,[r0] ; adds r1,#1 ; adc r2,r2,#0 ; strd r1,r2,[r0]  ← 非原子
  ⚠ 进位瞬间读到半值 → 时间倒退 49.7 天

⑩ ⭐ 按键去抖（deb.c 主机模拟）
  不去抖：   t=11/12/13/100 共 4 次跳变         ❌（真实只有 2 次）
  20 ms 去抖：t=33 确认按下、t=100 确认松开      ✅ 共 2 次事件

⑪ ⭐ 取时间成本（host.c，2×10⁷ 次循环，-O2，macOS arm64）
  millis()（读 volatile 全局）   1.63 ns/次
  clock_gettime(CLOCK_MONOTONIC) 21.13 ns/次    → 差 12.9 倍
  连续两次 clock_gettime 的差值：1000 ns
  ⚠ 实测的是 macOS arm64；Linux 走 vDSO 会更快，但仍是"比读全局变量贵一个量级"

⑫ 算式推导（非实测，已标注）
  PSC/ARR：72 MHz 要 1 kHz → PSC=71 / ARR=999（计数频率凑成 1 MHz 最好算）
  16 位定时器最长周期：8 MHz 536.87 s ｜ 72 MHz 59.65 s ｜ 168 MHz 25.57 s
  SysTick 24 位上限：8 MHz 2097.15 ms ｜ 72 MHz 233.02 ms ｜ 168 MHz 99.86 ms
```

## 读完本篇你应该能回答

- SysTick 属于 ARM 内核还是 ST 外设？（**内核**，地址在 PPB `0xE000E010`）
- 8 MHz 的 F103 上 RVR 填多少？（**7999**，不是 8000；不减 1 一天多走 10.8 秒）
- 为什么 `millis() >= next` 是错的？（**49.7 天后永远不触发**，实测 `now=0x10` 时判假）
- 回绕安全写法要花多少额外指令？（**0 条**，实测就是 `subs` + `bmi`）
- 为什么 ISR 会凭空消失？（**向量表没写它 → `--gc-sections` 删掉**，链接不报错）
- 忙等循环在 `-Os` 下会怎样？（**整个消失，只剩 `bx lr`**）
- 用正确方案替换忙等要多花多少资源？（**8 字节**）
- 为什么 TIM2 配置比 SysTick 贵一倍？（**多一条开 `RCC_APB1ENR`**，28 B）
- `uint64_t` 毫秒为什么危险？（**`tick64` 是 4 条指令的非原子序列**，进位瞬间时间倒退）
- 一次真实按键不去抖会产生几次跳变？（实测 **4 次**，应该是 2 次）
- 裸机的 `g_ms` 对应 Linux 的什么？（**`jiffies`**；`time_after()` 和 `(int32_t)(a-b)` 是同一招）
- `clock_gettime()` 有多贵？（实测 **21.13 ns**，比裸机 `millis()` 贵 **12.9 倍**）

## 前置 / 后续

- 前置：[ch04 数字与位运算](../04-numbers-and-bitops/README.md)（unsigned 回绕是本篇地基）、
  [ch05 决策和控制语句](../05-control-flow-button/README.md)（按键去抖）、
  [ch10 中断](../10-interrupts/README.md)（向量表与 ISR）
- 后续：**ch20 FreeRTOS**——RTOS 心跳就是 SysTick，`xTaskDelayUntil` 是本篇判据的 RTOS 版
- **LDD- / TLPI 侧**：`jiffies` / `HZ` / `time_after()` / `timerfd` / `hrtimer`
  是本篇概念的内核版；`clock_gettime()` 的 21 ns 解释了
  `CLOCK_MONOTONIC` vs `CLOCK_REALTIME` 的选择为何重要
- **HFT 侧**：**时间戳不是免费的**——这是本篇对低延迟工作最直接的一条

## 实验复现

```sh
cd /tmp/ch19lab

# ① 回绕安全 vs 朴素写法（主机）
clang -O2 -o wrap wrap.c && ./wrap

# ② 去抖模拟（主机）
clang -O2 -o deb deb.c && ./deb

# ③ 取时间成本（主机，-O2，2×10⁷ 次）
clang -O2 -o host host.c && ./host

# ④ 各 -O 级别下等待循环的存活（Cortex-M3）
CL=/Users/a0000/micromamba/envs/cdev/bin/clang
for O in O0 O1 O2 Os; do
  $CL --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -$O -ffreestanding -c wait.c -o wait_$O.o
  /Users/a0000/micromamba/envs/cdev/bin/llvm-objdump -d wait_$O.o
done

# ⑤ 64 位读写的原子性
$CL --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -c atomic.c -o atomic.o
/Users/a0000/micromamba/envs/cdev/bin/llvm-objdump -d atomic.o

# ⑥ 裸机尺寸对比（真实链接）
LDS=/Users/a0000/WorkBuddy/2026-09-04-17-26-07/STM32-/01-stm32/00-toolchain-clang/linker.ld
LD=/Users/a0000/micromamba/envs/cdev/bin/ld.lld
CF="--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib -ffunction-sections -fdata-sections"
$LD -T $LDS --gc-sections -o app_cfg.elf  v19.o app_cfg.o   && llvm-size app_cfg.elf   # 36
$LD -T $LDS --gc-sections -o app_busy.elf v19.o app_busy.o  && llvm-size app_busy.elf  # 52
$LD -T $LDS --gc-sections -o app_tick.elf v19.o app_tick.o  && llvm-size app_tick.elf  # 60
$LD -T $LDS --gc-sections -o app_tim.elf  vec_tim.o app_tim.o && llvm-size app_tim.elf # 64

# ⑦ ⭐ 向量表 16 项 vs 2 项（本篇最重要的实验）
$LD -T $LDS --gc-sections -o vt16.elf vec16.o app_tick2.o && llvm-nm -S vt16.elf | grep SysTick  # 在
$LD -T $LDS --gc-sections -o vt2.elf  vec2.o  app_tick2.o && llvm-nm -S vt2.elf  | grep SysTick  # 没了
```

⚠ **本机环境限制（诚实标注）**：

1. **没有真机**——所有"上电之后会怎样"的结论只到"链接通过 + 反汇编正确"这一层；
   波形 / 时序 / ISR 抖动**未实测**。
2. **APB1 预分频 ≠ 1 时定时器时钟 = PCLK1 × 2**（RM0008）**未实测**，
   待 `01-stm32/06-timer` 建成后用示波器验证。
3. **PSC / ARR 数值表、16 位最长周期、SysTick 24 位上限**均为**算式推导**，非实测。
4. **NUCLEO-F103RB 上电 HSI 8 MHz** 来自公开规格，未测量。
5. **`clock_gettime` 实测值是 macOS arm64**，Linux 走 vDSO 数值会不同。
6. **`deb.c` 里的按键抖动波形是我编的模型**，不是真机波形
   （真实机械按键抖动通常 5~20 ms，结论不变）。
7. **中断进出约 20~30 个周期**引自常识，**未实测**。
