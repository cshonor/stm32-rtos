# 第 10 章 中断 —— 章节导航

> 书：第 10 章 中断（原书 p135–153）
> 对应实验：Cortex-M 交叉（`--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding`，
> `-Os` 反汇编 + `-fstack-usage` + `llvm-size --print-size`）+ 主机侧环形缓冲行为验证

## 这一章在讲什么

书这一章的推进顺序很好：**先让你体会轮询的浪费（10.1），
再用串口中断改进（10.2–10.3），最后引入缓冲区（10.4）**。

本篇顺着这个顺序，但补上书里讲得不够的三件事：

1. **Cortex-M 的中断是硬件自动压栈的**——所以 ISR 在 C 里就是普通函数，
   这和其他架构（AVR/PIC/ARM7）完全不同，是极易混淆的点；
2. **NVIC 的使能是"两道门"**——外设的中断使能位 + NVIC 的 ISER，
   漏一个就不进中断（和"漏开时钟"并列的两大静默失败）；
3. **ISR 里不能做什么**——这是代码规范问题，但在裸机上是**正确性问题**。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 10.1 | 轮询与中断 | [10.1-轮询与中断](10.1-轮询与中断.md) |
| 10.2 | 串口 I/O 中断 | [10.2-串口IO中断](10.2-串口IO中断.md) |
| 10.3 | 中断例程 | [10.3-中断例程](10.3-中断例程.md) |
| 10.4 | 用缓冲区提速 | [10.4-用缓冲区提速](10.4-用缓冲区提速.md) |
| 10.5 | 完整程序 | [10.5-完整程序](10.5-完整程序.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p135–153），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（10.1–10.5），
> 顶层索引原先写的 `10.1–10.7` 是错的，已订正。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 10.1 讲"轮询浪费" | 量化：115200 下等一个字节 = **6249 个时钟周期**（86.8 µs @ 72 MHz）；并指出**中断不改变吞吐，只改变 CPU 占用** |
| 10.2 讲"打开串口中断" | 补上**两道门**（外设 IE + NVIC_ISER）；实测 `interrupt` 属性会生成**多余 push/pop + bfc 栈对齐**（16 条 vs 13 条，且 clang 不警告） |
| 10.3 讲"写 ISR" | 补上**标志清除没有统一规则**（USART 读 DR 清 vs EXTI **写 1 清**）；临界区实测（`mrs primask`/`cpsid i`/`msr`） |
| 10.4 讲"缓冲区提速" | 实测：容量是 **SIZE−1**（64 → 63）；`&(SIZE-1)` 11 条指令 vs `% 60` 19 条；**单写者**是不关中断的唯一理由 |
| 10.5 给完整程序 | 实测资源：**294 字节 `.text` + 76 字节 `.bss`**，ISR 路径 0 栈；补上 ORE/溢出计数/帧边界/超时 |
| 书里没提 | **发送中断的风暴问题**：TXE 是状态标志（不是事件），必须"有数据才开、发完就关" |

## 核心实测数据（本章的锚点）

```
① 轮询的代价（115200 8N1）
1 bit = 8.68 us | 1 字节 = 86.8 us | 吞吐 11520 B/s
72 MHz 下等一个字节 = 6249 个周期
ISR 预算（10% CPU）：9600→104 us | 115200→8.7 us | 921600→1.1 us（要 DMA）

② ISR 加不加 interrupt 属性（-Os，Cortex-M3）
普通函数：13 条指令
  0: movw/movt → 8: ldr → a: lsls → c: it pl → e: bxpl lr → ... → 28: bx lr
__attribute__((interrupt))：16 条指令，编译无警告
  0: b5d0  push {r4, r6, r7, lr}        ← 多余
  6: f36f 0402  bfc r4, #0, #3          ← 多余：8 字节栈对齐
 38: bdd0  pop  {r4, r6, r7, pc}        ← 多余 + 语义可疑

③ 临界区（-Os）
crit_bad（无保护）：  ldr / adds / str            = 3 条，非原子
crit_ok （临界区）：  mrs r0,primask / cpsid i /
                     ldr / adds / str /
                     msr primask,r0              = 8 条
enable_disable：     cpsid i (b672) / cpsie i (b662)   ← 都是单条 16 位指令

④ 环形缓冲（-Os，Cortex-M3）
&(SIZE-1) 版 rb_put：11 条指令（and r2, r2, #0x3f）
% 60     版 rb_put_mod：19 条指令（umull + 移位，魔法数 0x88888889）
llvm-nm -u：空（常量除数被优化成乘法逆元，没拉进 udiv）
-fstack-usage：rb_put 0 / rb_get 0 / rb_put_mod 0

⑤ 环形缓冲行为（主机侧实测）
put ok=63 full_reject=137 head=63 tail=0     ← 容量 = SIZE-1 = 63
get n=63 first=0 last=62
after 300 put/get: head=43 tail=43 max_head=63（始终 < 64）

⑥ 完整程序资源（-Os）
rb_put             32 B
rb_get             36 B
USART1_IRQHandler  66 B
uart1_putc         20 B
uart1_init        100 B
─────────────────────────
.text 294 B   .data 0   .bss 76 B（g_rx_rb 72 + g_rx_overflow 4）
llvm-nm -u：空（零外部依赖）
```

## 读完本章你应该能回答

- 轮询和中断的"速度"差在哪？（**吞吐一样**，差在等待期间 CPU 能不能干别的）
- 为什么"发送可以轮询、接收必须中断"？
- 轮询的三个优点是什么？HardFault 时哪个能用？
- 两道门是什么？漏了会怎样？`NVIC_ISPR`/`IABR` 怎么用来定位？
- 实测里 `__attribute__((interrupt))` 加了会怎样？clang 会警告吗？
- 为什么 TXE 中断会导致中断风暴？
- 中断标志怎么清？USART 和 EXTI 有什么不同？
- 临界区为什么必须恢复 PRIMASK 原值？
- 环形缓冲为什么单写者就不需要关中断？
- 64 的缓冲能装几个字节？（实测 63）
- 完整程序占多少 Flash / RAM / 栈？
- ORE 为什么会导致 ISR 风暴？

## 前置 / 后续

- 前置：[第 4 章 数字和位操作](../04-numbers-and-bitops/README.md)（`& (SIZE-1)`、写 1 生效）、
  [第 5 章 volatile](../05-control-flow-button/README.md)（`wait_bad` 实测）、
  [第 6 章 数组指针](../06-arrays-pointers-strings/README.md)（环形缓冲的 `buf`）、
  [第 7 章 栈帧](../07-stack-frame-functions/README.md)（ISR 额外压 32 字节）、
  [第 9 章 串口](../09-uart-serial/README.md)（轮询发送的完整实测）
- 后续：[ch11 链接器](../ch11-linker.md)（`.bss` 布局、栈预算、链接期 `ASSERT`）、
  [ch19 SysTick](../ch19-systick-and-timer.md)（最简单的中断，比 EXTI 少两步骤）、
  [ch20 FreeRTOS](../README.md)（`xQueueSendFromISR` 把环形缓冲换成 RTOS 队列）
- **LDD- 侧**：Linux 的"上半部/下半部"在裸机上就是本章的
  **"ISR 入队 + 主循环处理"**；`spin_lock_irqsave` 对应 `__disable_irq()` +
  恢复 PRIMASK。学两遍，机制同源。
