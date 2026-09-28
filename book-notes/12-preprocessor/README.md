# 第 12 章 预处理器 —— 章节导航

> 书：第 12 章 预处理器（原书 p174–185）
> 对应实验：主机侧运行实测（clang 23.1.0）+ `clang -E -P` / `-E -dM` 展开对照
> + Cortex-M3 交叉（`-Os`）体积对照

## 这一章在讲什么

**预处理器是编译器看到的第一个东西**，也是最容易被当成"就是替换文本"的一步。

它**确实是**替换文本——但正因为是纯文本替换，才有两个经典陷阱：

1. **缺括号**：`SQUARE_BAD(3+1)` = **7**（不是 16）；
2. **参数被求值多次**：`MAX(READ_DR(), READ_DR())` 在裸机上**读了 3 次**寄存器。

第二个在嵌入式里是**数据丢失级**的 bug——
读 USART 的 DR 是"消费型"操作（读一次清一次 RXNE），
求值 3 次 = **丢 3 个字节**，但代码看起来只用了 2 个。

一句话概括全章：

> **宏是纯文本替换：没有类型、没有作用域、参数可能求值多次。
> 它的价值在"编译期常量"和"编译期裁剪"，不在"代替函数"。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 12.1 | 简单宏 | [12.1-简单宏](12.1-简单宏.md) |
| 12.2 | 带参数的宏 | [12.2-带参数的宏](12.2-带参数的宏.md) |
| 12.3 | 代码宏 | [12.3-代码宏](12.3-代码宏.md) |
| 12.4 | 条件编译 | [12.4-条件编译](12.4-条件编译.md) |
| 12.5 | 定义符号的位置 | [12.5-定义符号的位置](12.5-定义符号的位置.md) |
| 12.6 | 命令行定义的符号 | [12.6-命令行定义的符号](12.6-命令行定义的符号.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p174–185），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（12.1–12.6）；
> 顶层索引原先写的 `12.1–12.8` 是错的，已订正为 **12.1–12.6**。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 12.1 讲简单宏 | 补上"`-E -P` 是排查宏问题的唯一武器"；实测地址宏被折叠成 `movw`/`movt` 立即数（`llvm-size` 的 `data = 0`）；讲清为什么 `const` 替代不了宏（C 里 `const` 不是常量表达式） |
| 12.2 讲带参数的宏 | **跑出真数字**：`SQUARE_BAD(3+1)` = **7**；`MAX(READ_DR(),READ_DR())` 读了 **3 次**（不是 2 次）；⚠ `MAX(i++,j++)` **编译器不警告**（`?:` 有顺序点），`TWICE(k++)` 才有 `-Wunsequenced` |
| 12.3 讲代码宏 | ⚠ 实测**代码宏不省机器码**：生成的函数 28 B，手写 `static inline` 也是 28 B。收益是"少写源码"，代价是**调试器里没有行号** |
| 12.4 讲条件编译 | 补上 **`#if` vs `#ifdef` 三态表**（`-DFOO=0` 时 `#ifdef`→1、`#if`→0）；**头文件守卫重名会静默吞掉整个头文件**；`assert` 在裸机**链接失败**（`U __assert_func`）；**一个 assert 就 62 字节**（86 → 24，主要是 `__FILE__` 字符串） |
| 12.5 讲定义位置 | ⚠ 实测**宏没有块作用域**（函数体里 `#define` 会泄漏到文件尾）；重定义**值相同合法、值不同只有警告**且后定义的生效 |
| 12.6 讲命令行定义 | ⚠ 实测**忘了给 `-D` 不是"用默认值"**：当值用 → 编译错误；**在 `#if` 里 → 静默当 0**（最危险，日志被裁掉不报错） |
| 书里没提 | `-E -dM` 查预定义宏；`-U` 的顺序语义；字符串宏的两层引号；交叉目标**没有 libc 头文件**（`<assert.h>` 找不到） |

## 核心实测数据（本章的锚点）

```
① clang -E -P 展开（m1.c）
int result  = (3 + 1*3 + 1);      ← SQUARE_BAD(x) (x*x)
int result2 = ((3 + 1)*(3 + 1));  ← SQUARE_OK(x)  ((x)*(x))
int r3      = ((1) > (2) ? (1) : (2));
const char *s1 = "SQUARE_OK(2)";  ← STRINGIFY：# 的参数不展开
const char *s2 = "3";             ← XSTR(VER)：包两层才展开
int myVar = 42;                   ← CONCAT(my, Var)：## 粘合
unsigned b = (1u << (5));

② 运行实测（-O0，主机）
SQUARE_BAD(3+1) = 7                        ← 不是 16
SQUARE_OK (3+1) = 16
MAX(i++,j++): m=5  i=4 j=6                 ← j 加了两次（4→6）
TWICE(k++):   t=11  k=7                    ← k 加了两次（5→7），有 -Wunsequenced 警告
MAX(READ_DR(),READ_DR()) 读了几次 DR: 3    ← ⚠ 不是 2 次，是 3 次

③ 代码宏 vs 手写 inline（Cortex-M3，-Os）
llvm-nm --print-size -S cm.o：
  00000000 0000001c T use_macro      ← 28 字节
  00000000 0000001c T use_plain      ← 28 字节（一模一样）
use_macro 反汇编：
  0: movw r0,#0x80c / 4: movt r0,#0x4001   ← 0x4001080c 进立即数
  8: ldr r1,[r0] / a: orr r1,r1,#0x20 / e: str r1,[r0]
 10: ldr r1,[r0] / 12: bic r1,r1,#0x20 / 16: str r1,[r0]
 18: ldr r0,[r0] / 1a: bx lr
llvm-size cm.o：text 72  data 0  bss 0      ← 地址不占 .data

④ #if vs #ifdef 三态
                #ifdef FOO    #if FOO
无 -D              0             0
-DFOO=0            1  ⚠          0
-DFOO              1             1

⑤ 头文件守卫重名（两个头文件都用 CONFIG_H）
$ clang -E -P -I. guard.c
1=1
FROM_B=FROM_B            ← ⚠ b.h 被整段跳过，FROM_B 没定义
$ clang -fsyntax-only -I. guard2.c
guard2.c:3:9: error: use of undeclared identifier 'FROM_B'   ← 报错在使用处

⑥ #error 卡住未指定板子
$ clang -fsyntax-only board.c
board.c:6:4: error: "未指定板子：请 -DBOARD_NUCLEO_F103RB 或 -DBOARD_F407_DISCOVERY"
board.c:8:11: error: use of undeclared identifier 'LED_PIN'   ← ⚠ #error 不停止预处理
$ clang -E -P -DBOARD_F407_DISCOVERY board.c → int pin = 9;

⑦ NDEBUG 的体积影响（Cortex-M3，-Os，一个 assert）
                  无 NDEBUG      -DNDEBUG
.text                86 B          24 B      ← 省 62 B
.rodata             "asrt4.c\0main\0g == 2\0"  无
llvm-nm -u       U __assert_func     无
$ ld.lld -T linker.ld -e main asrt2.o
ld.lld: error: undefined symbol: __assert_func

⑧ 宏的作用域
void f(void){ #define INNER 1 ... #undef INNER }  → 文件尾 #ifdef INNER 为假 ✅
去掉 #undef                                        → 文件尾 #ifdef INNER 为真 ⚠ 泄漏

⑨ 宏重定义
#define FOO 1 / #define FOO 1   → 合法，无输出
#define FOO 1 / #define FOO 2   → warning: 'FOO' macro redefined [-Wmacro-redefined]
                                   后定义的生效（FOO = 2）

⑩ 命令行定义
$ clang -E -P -DFW_VERSION='"1.2.3"' -DCFG_BAUD=115200 -DLOG_LEVEL=2 -DFEATURE_X cmd.c
const char *fw = "1.2.3";   int baud = 115200;   int dbg = 2;   int has_x = 1;
$ clang -E -dM -DCFG_BAUD=115200 cmd.c | grep -E "CFG_BAUD|LOG_LEVEL"
#define CFG_BAUD 115200        ← 只有它（LOG_LEVEL 没给）
$ clang -E -P -DCFG_BAUD=115200 -UCFG_BAUD -DCFG_BAUD=9600 cmd.c
int baud = 9600;               ← -U 只取消它之前的
漏给 -D（当值用）：
cmd.c:3:19: error: use of undeclared identifier 'LOG_LEVEL'
漏给 -D（在 #if 里）：静默当 0，不报错 ⚠
```

## 读完本章你应该能回答

- `SQUARE_BAD(3+1)` 为什么是 7？括号该加在哪两处？
- `MAX(READ_DR(), READ_DR())` 读了几次寄存器？裸机上后果是什么？
- 编译器会警告 `MAX(i++, j++)` 吗？（实测：**不会**）
- 为什么 `#` 和 `##` 的参数"不展开"？怎么让它展开？
- 代码宏能省 Flash 吗？（实测：**不能**，28 B vs 28 B）
- `ARRAY_LEN(a)` 传进函数为什么错？
- `-DFOO=0` 时 `#ifdef FOO` 和 `#if FOO` 分别是真还是假？
- 两个头文件用了同一个守卫名会怎样？报错在哪？
- `#error` 会让预处理停下吗？
- `assert` 在裸机上为什么链接失败？三条出路是什么？
- 一个 `assert` 占多少 Flash？主要是哪部分？（62 B，主要是 `__FILE__`）
- 宏有没有块作用域？（实测：**没有**）
- 重复 `#define` 会报错吗？（值不同只有**警告**）
- 忘了给 `-D` 会怎样？三种用法的结果各是什么？
- 怎么确认 `-D` 真的生效了？

## 前置 / 后续

- 前置：[第 4 章 位操作](../04-numbers-and-bitops/README.md)（`BIT(n)` / `REG32()` 的裸机主力用法）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（`enum` / `_Static_assert` 替代宏）、
  [第 10 章 中断](../10-interrupts/README.md)（读 DR 清 RXNE——重复求值为什么致命）、
  [第 11 章 链接器](../11-linker/README.md)（宏展开后的 `.rodata` 在 map 里能看到）
- 后续：[第 17 章 模块化编程](../17-modular-programming/README.md)（头文件守卫是模块化的基础设施）
- **LDD- 侧**：内核的 `BUILD_BUG_ON()`、`IS_ENABLED()`、
  以及 Kconfig 生成的 `CONFIG_*` 宏，都是本章机制的**规模化应用**：
  - `IS_ENABLED(CONFIG_X)` 就是"把 `#ifdef` 变成值判断"，
    正是本章 [12.4](12.4-条件编译.md) 讲的 `-DFOO=0` 陷阱的对策；
  - `container_of` 是 [12.3](12.3-代码宏.md) 那个宏的标准实现；
  - `pr_debug()` 的"编译期裁掉"就是 `#if LOG_LEVEL >= 2` 的企业版。

## 实验复现

```sh
# ① 看宏展开
clang -E -P m1.c                  # 展开，去掉行号
clang -E -dM m1.c                 # 列出所有已定义的宏

# ② 跑出两个陷阱的真数字
clang -O0 -Wall -o m2 m2.c && ./m2

# ③ 代码宏 vs 手写 inline（交叉）
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os \
      -ffunction-sections -c cm.c -o cm.o
llvm-nm --print-size -S cm.o
llvm-size cm.o

# ④ NDEBUG 的体积账
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os \
      -c asrt4.c -o asrt4.o && llvm-size asrt4.o && llvm-nm -u asrt4.o
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os \
      -DNDEBUG -c asrt4.c -o asrt4.o && llvm-size asrt4.o && llvm-nm -u asrt4.o
```

⚠ **交叉编译没有 libc 头文件**：
本仓库只用 clang + ld.lld，没装 newlib，
所以交叉侧 `#include <assert.h>` / `<string.h>` **会报 file not found**
（实测：`fatal error: 'assert.h' file not found`）。
主机侧能找到。这是环境事实，不是代码问题。
