# 第 8 章 复杂数据类型 —— 章节导航

> 书：第 8 章 复杂数据类型（原书 p98–118）
> 对应实验：主机侧 clang 23.1.0（布局 / 字节序 / 类型兼容性）+ Cortex-M 交叉
> （`--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding`，`offsetof` + `_Static_assert` + 反汇编）

## 这一章在讲什么

在普通 C 书里，这一章是**语法课**：枚举、结构体、联合体、typedef。
在裸机上它是**硬件抽象的地基**——核心只有一句：

> **结构体就是寄存器块的地图。**（[8.12](8.12-结构体与嵌入式编程.md)）

芯片把一组相关的寄存器排在连续地址上（GPIOA 的 CRL/CRH/IDR/ODR/BSRR/BRR/LCKR
依次落在 `0x40010800 + 0x00/04/08/0C/10/14/18`），
而 C 的结构体正好描述"一段连续内存里每个偏移是什么"。
所以你可以把基址转成结构体指针，写 `GPIOA->BSRR` 而不是 `*(volatile uint32_t *)0x40010810`。

**机器码完全一样**（[8.8 实测](8.8-结构体指针.md)），
差别在于结构体写法能用 **编译期断言把偏移钉死**——
把"灯不亮"变成"编译失败，实际 16 你写 20"。

本章的三件工具：**`offsetof` + `_Static_assert`（布局校验）+ 反汇编（代价）+ `-Wpadded`（填充报警）**。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 8.1 | 枚举 | [8.1-枚举](8.1-枚举.md) |
| 8.2 | 预处理技巧和枚举 | [8.2-预处理技巧和枚举](8.2-预处理技巧和枚举.md) |
| 8.3 | 结构体 | [8.3-结构体](8.3-结构体.md) |
| 8.4 | 内存中的结构体 | [8.4-内存中的结构体](8.4-内存中的结构体.md) |
| 8.5 | 访问未对齐数据 | [8.5-访问未对齐数据](8.5-访问未对齐数据.md) |
| 8.6 | 结构体初始化 | [8.6-结构体初始化](8.6-结构体初始化.md) |
| 8.7 | 结构体赋值 | [8.7-结构体赋值](8.7-结构体赋值.md) |
| 8.8 | 结构体指针 | [8.8-结构体指针](8.8-结构体指针.md) |
| 8.9 | 结构命名 | [8.9-结构命名](8.9-结构命名.md) |
| 8.10 | 联合体 | [8.10-联合体](8.10-联合体.md) |
| 8.11 | 创建自定义类型 | [8.11-创建自定义类型](8.11-创建自定义类型.md) |
| **8.12** | **结构体与嵌入式编程** | **[8.12-结构体与嵌入式编程](8.12-结构体与嵌入式编程.md)（本章核心）** |
| 8.13 | typedef | [8.13-typedef](8.13-typedef.md) |
| 8.14 | 函数指针与 typedef | [8.14-函数指针与typedef](8.14-函数指针与typedef.md) |
| 8.15 | typedef 和 struct | [8.15-typedef和struct](8.15-typedef和struct.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p98–118），故不列单节页码。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 把"对齐/填充"当内存浪费讲 | **在裸机上是功能错误**：偏移错了 `GPIOA->BSRR` 写到别的寄存器（[8.4](8.4-内存中的结构体.md)） |
| 把 `packed` 当中性技巧讲 | **寄存器结构体禁用**：偏移错位 + M0 上未对齐访问 **HardFault**（[8.12 Q3](8.12-结构体与嵌入式编程.md)） |
| 讲"结构体可以整体赋值" | 补上代价：大结构体赋值生成 `__aeabi_memcpy`，且**非原子**（撕裂读）（[8.7](8.7-结构体赋值.md)） |
| 讲"结构体传参" | 实测传值 vs 传指针：64 B 结构体在 `-O0` 下栈用量 **112 B vs 4 B**（28 倍）（[8.8](8.8-结构体指针.md)） |
| 把 `typedef` 当风格问题 | 对**函数指针**而言是唯一可读的写法（[8.14](8.14-函数指针与typedef.md)）；对**指针别名**而言 `#define` 会出错（[8.11](8.11-创建自定义类型.md)） |
| 讲递归/联合体的语法 | 联合体在裸机的主力用途是"同一寄存器的三种看法"（[8.10](8.10-联合体.md)） |
| 讲"函数指针就是地址" | 补上 Cortex-M 的 **Thumb 位**：手写常量要 `+1`（[8.14 Q3](8.14-函数指针与typedef.md)） |

## 核心实测数据（本章的锚点）

```
① 布局（Mac 与 Cortex-M3 同数）
S1{char,int,char}   size=12  off(a)=0 off(b)=4 off(c)=8     ← 6 字节填充
S2{int,char,char}   size=8                                   ← 换个顺序省 4 字节
packed P{char,int}  size=5   off(b)=1                        ← 未对齐
union U{uint32_t,uint8_t[4]}  size=4
u.i=0x12345678 → b[0]=0x78 b[1]=0x56 b[2]=0x34 b[3]=0x12     ← 小端

② -Wpadded
warning: padding struct 'struct S1' with 3 bytes to align 'b'
warning: padding size of 'struct S1' with 3 bytes to alignment boundary

③ 寄存器地图校验（Cortex-M）
_Static_assert(offsetof(GPIO_TypeDef, BSRR) == 0x10)   → 通过
故意写成 0x14 →
  error: static assertion failed ... '16 == 20'

④ -> 零成本（-O0/-Os/-O2 三档一致）
via_arrow / via_deref / via_offset  →  都是 movw/movt/str

⑤ 传参代价（-fstack-usage, -O0）
huge_by_value (64B 结构体)  112 字节  ~40 条指令
huge_by_ptr   (指针)          4 字节   7 条指令

⑥ 函数指针
fp=0x100d1be44 add=0x100d1be44   fp(3,4)=7    改指向 sub → -1
-O0: blx r2（间接）   -Os: bx r3（尾调用）
直接调用 -Os 被内联成一条 add r0,r1

⑦ typedef 陷阱
#define PCHAR_DEF char *  →  sizeof(a)=8 sizeof(b)=1      ← b 不是指针
typedef char *pchar_t     →  sizeof(c)=8 sizeof(d)=8
const str_t p             →  编译器诊断：aka 'char *const'（const 的是指针）
```

## 读完本章你应该能回答

- 为什么 `S1` 是 12 字节而 `S2`（同样成员换个顺序）只有 8？（填充规则）
- 寄存器结构体为什么**不能**加 `packed`？加了会怎样？
- `GPIOA->BSRR` 和 `*(volatile uint32_t *)0x40010810` 哪个更快？（一样快，为什么还要用前者？）
- `_Static_assert(offsetof(...))` 抓的是什么类型的 bug？不写会怎样？
- 结构体什么时候可以传值，什么时候必须传指针？（16 字节判据）
- `-Os` 下 `.su` 报 0，是不是就没有栈成本？（可能是假象，为什么？）
- 联合体在裸机上的主力用途是什么？位域为什么不能做原子修改？
- `const str_t p` 到底 const 了谁？
- 函数指针在 Cortex-M 上为什么要 `+1`？
- 四种 `typedef struct` 写法该选哪个？

## 前置 / 后续

- 前置：[第 4 章 数字和位操作](../04-numbers-and-bitops/README.md)（位操作、读-改-写）、
  [第 6 章 数组、指针和字符串](../06-arrays-pointers-strings/README.md)（数组退化）、
  [第 7 章 局部变量和函数](../07-stack-frame-functions/README.md)（栈帧与 `.su`）
- 后续：[第 9 章 串口输出](../09-uart-serial/README.md)（UART 驱动用"结构体 + 回调"成型）、
  [ch10 中断](../10-interrupts/10.2-串口IO中断.md)（向量表就是 `isr_t` 数组）、
  [ch17 模块化编程](../ch17-modular-programming.md)（结构体 + 函数指针 = 裸机的"面向对象"）
- 横向：[11.2 链接过程](../11-linker/11.2-链接过程.md)（链接期 `ASSERT` 是编译期断言的补充）、
  [16.1 数字表示](../16-floating-point/16.1-数字表示.md)（`0.1f` 的位模式 `0x3dcccccd`）
- **LDD- 侧**：Linux 驱动的 `struct file_operations` 就是"函数指针表"的终极形态；
  `ioremap()` 之后用结构体映射寄存器，和本章 [8.12](8.12-结构体与嵌入式编程.md) 完全同源。
