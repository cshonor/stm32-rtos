# 第 9 章 STM 上的串口输出 —— 章节导航

> 书：第 9 章 STM 上的串口输出（原书 p119–134）
> 对应实验：Cortex-M 交叉（`--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding`，
> `-O0`/`-Os`/`-O2` 三档反汇编 + `-fstack-usage` + `llvm-size`）+ macOS 26.6.2 主机侧串口实测

## 这一章在讲什么

PC 上 `printf("hello")` 是一行；裸机上它是一整章。因为 `printf` 底下是：

```
printf → (libc) → write(2) → 系统调用 → 内核 tty 驱动 → 串口芯片
```

裸机上**中间三层全没了**，只剩"你 → UART 数据寄存器"。所以本章的实质是：

1. **初始化 UART**：开时钟 → 配引脚复用 → 算波特率 → 使能；
2. **写一个字符**：等 `TXE` → 写 `DR`；
3. **把 `printf` 接过来**：自己写 `mini_printf`（因为没有 libc）。

第 3 步书里讲得轻（它到 `putchar` 就停了），
本仓库补上——**`printf` 可用与否直接决定后面所有实验的调试效率**。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 9.1 | 一次写一个字符的字符串 | [9.1-一次写一个字符的字符串](9.1-一次写一个字符的字符串.md) |
| 9.2 | 定义我们的 putchar | [9.2-定义我们的putchar](9.2-定义我们的putchar.md) |
| 9.3 | 串行输出 | [9.3-串行输出](9.3-串行输出.md) |
| 9.4 | 串行通信简史 | [9.4-串行通信简史](9.4-串行通信简史.md) |
| **9.5** | **串口 Hello World** | **[9.5-串口HelloWorld](9.5-串口HelloWorld.md)（本章核心）** |
| 9.6 | Windows 与设备通信 | [9.6-Windows与设备通信](9.6-Windows与设备通信.md) |
| 9.7 | Linux 和 macOS 与设备通信 | [9.7-Linux和macOS与设备通信](9.7-Linux和macOS与设备通信.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p119–134），故不列单节页码。
> 9.6（Windows）**未在本机实测**（本机 macOS），已在篇首标注；9.7 的 macOS 部分是实测的。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 9.1 讲"字符串逐字符写" | 补上代价实测：`volatile` 差一个，**`-Os` 下变成"只读一次 + 无限自跳"（死锁）**，不是"循环被删掉" |
| 9.2 讲"我们的 putchar" | 补上 TXE vs TC 的区分（**关串口前必须等 TC**，否则丢最后一个字节） |
| 9.3 讲"串行输出" | 补上数字：整条输出链路 **340 字节 Flash、40 字节栈、`llvm-nm -u` 零依赖** |
| 9.4 讲历史 | 补上**全波特率误差表**（8 MHz / 72 MHz × 8 档），并给出 5% 极限的推导 |
| 9.5 讲初始化 | 补上 M3/M0 除法指令对照实测：**M3 有 `udiv`，M0 没有**（要 `__aeabi_uidiv`） |
| 9.5 用 USART1 | 指出 **NUCLEO-F103RB 上是 USART2(PA2/PA3) 接 ST-Link**，USART1 收不到 |
| 书讲 `putchar` 就停 | 补上 `mini_printf` 的完整实现与 `do-while` 的 `v==0` 边界 |
| 9.6/9.7 讲工具操作 | macOS 部分实测：`/dev/cu.usbmodem2103`、**默认 9600**、`screen` 自带、`stty -f` 不持久 |

## 核心实测数据（本章的锚点）

```
① volatile 差一个的代价（-Os，Cortex-M3）
volatile 版：
       8: 680a   ldr  r2, [r1]        ← 32 位读，在循环体内
       a: 0612   lsls r2, r2, #0x18
       c: d5fc   bpl  0x8             ← 真循环
       e: 6048   str  r0, [r1, #0x4]
非 volatile 版：
      1a: 780a   ldrb r2, [r1]        ← ⚠ 窄化成 8 位读，且只读一次
      1e: bf44   itt  mi
      20: 6048   strmi r0, [r1, #0x4]
      24: e7fe   b    0x24            ← 不满足 → 跳自己，永久死锁

② 输出链路成本（-Os）
llvm-size:  text=340 B  data=0  bss=0      （-O0: 548 B）
llvm-nm -u: （空 —— 零外部依赖）
-fstack-usage: mini_printf 40 B, put_uint 24 B   （-O0: 48 / 48 / uart1_putc 4）

③ 波特率误差（Python 按 RM0008 算）
8 MHz  : 9600 +0.04% | 115200 +0.64% | 460800 +2.12% ⚠ | 921600 -3.55% ⚠
72 MHz : 9600  0.00% | 115200  0.00% | 921600 +0.16% ✅
误配   : 以为 72 MHz 写 BRR=625，实际 8 MHz → 12800 baud（差 9 倍，满屏乱码）

④ 除法指令（同一行 BRR 计算）
cortex-m3: udiv ×1，llvm-nm -u 无未定义符号   ← M3 有硬件除法
cortex-m0: udiv ×0，U __aeabi_uidiv + bl      ← M0 没有

⑤ uart1_init: 28 条指令（-Os）
     时钟 → movw/movt + ldr/orrs/str
     引脚 → 4 组 ldr/bic|orr/str（读-改-写）
     BRR  → add.w (pclk+baud/2) → udiv → str
     CR1  → movw + str

⑥ 主机侧（macOS 26.6.2 实测）
/dev/cu.usbmodem2103  存在（crw-rw-rw- root wheel）
stty -a < /dev/cu.usbmodem2103 → speed 9600 baud; cs8 -parenb -cstopb -crtscts
stty -f ... 115200 之后再看 → 仍是 9600（关闭即重置）
which screen → /usr/bin/screen（系统自带）；minicom 未装；pyserial 未装
```

## 读完本章你应该能回答

- `volatile` 差一个，`uart1_putc` 会变成什么？（不是"循环消失"——是**只读一次 + 死锁**）
- `TXE` 和 `TC` 有什么区别？关串口前该等哪个？
- 115200 8N1 下，发一个字节要多久？一行 40 字符的日志要多久？
- 自己写 `mini_printf` 占多少 Flash / 栈？有没有外部依赖？
- 波特率误差的安全上限是多少？怎么推导出来的？
- 为什么 8 MHz 下 115200 有 0.64% 误差，而 72 MHz 下是 0？
- M3 和 M0 在"算波特率"这件事上差在哪？
- `put_uint` 为什么必须用 `do-while`？
- 初始化四步漏任意一步，分别是什么现象？
- NUCLEO-F103RB 上到底哪个 USART 接到板载 USB 口？
- macOS 上为什么要用 `/dev/cu.*` 而不是 `/dev/tty.*`？

## 前置 / 后续

- 前置：[第 4 章 数字和位操作](../04-numbers-and-bitops/README.md)（位操作、读-改-写）、
  [第 5 章 决策和控制语句](../05-control-flow-button/README.md)（`volatile` 等待循环）、
  [第 6 章 数组、指针和字符串](../06-arrays-pointers-strings/README.md)（`'\0'` 与字符串）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（把裸地址宏换成寄存器结构体）
- 后续：[ch10 中断](../10-interrupts/10.4-用缓冲区提速.md)（**接收必须走中断 + 环形缓冲**）、
  [ch11 链接器](../ch11-linker.md)（`.rodata` 里的日志字符串）、
  [ch19 SysTick](../ch19-systick-and-timer.md)（给日志加毫秒时间戳）
- 横向：[ch12 预处理器](../ch12-preprocessor.md)（`__FILE__`/`__LINE__` 的 Flash 代价）
- **LDD- 侧**：Linux 的 `printk` → 串口驱动 → `uart_driver`，
  层次和本章完全对应，只是中间几层是内核写的。
