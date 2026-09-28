# A.1 项目创建清单

> 书：附录「项目创建清单」（原书 p243）
> 下一篇：[A.2 清单每步的实测数据](A.2-清单每步的实测数据.md)
> 对应实验：本次**从零实测**（`/tmp/applab` 里真的建了一个能链出 `.bin` 的最小工程）

## 书这一节讲什么

⚠ **诚实前提**：原书 p243 的清单原文**我手头没有**（无电子版），
所以**不声称"这就是书里的那张清单"**。

我能负责任地写的是：**本仓库实际建一个裸机项目时走过的每一步**——
每一步的命令、产物、尺寸都在 [A.2](A.2-清单每步的实测数据.md) 里实测过。
按 [18.1](../18-next-steps/18.1-学会写作.md) 的纪律：**只记我实测的**。

一句话概括清单的作用：

> **裸机项目没有"新建工程向导"帮你把该有的东西都放好。
> 少一样东西，链接器多半不会报错，而是让你上电后得到一个静默死掉的板子。**

## 一、九步清单

| # | 步骤 | 产物 | 漏了会怎样（实测见 [A.3](A.3-做错会怎样.md)） |
|---|---|---|---|
| 1 | 定芯片与内存布局 | Flash/RAM 起始与长度 | RAM 越界，跑飞 |
| 2 | 写链接脚本（`ENTRY` + `KEEP`） | `linker.ld` | ⭐ 漏 `KEEP` → **向量表被删**，入口变 `0x8000001` |
| 3 | 写启动文件（向量表 + `Reset_Handler`） | `startup.c/.S` | 没有栈指针，第一条指令就崩 |
| 4 | `Reset_Handler` 里**搬 `.data`、清 `.bss`** | —— | 全局变量初值是 RAM 随机值 |
| 5 | 写应用 `main.c` | `main.c` | —— |
| 6 | 编译（`-ffreestanding -nostdlib` …） | `.o` | 拉进 host libc → 链接失败 |
| 7 | 链接（`--gc-sections` + `-Map`） | `.elf` + `.map` | ⭐ `--gc-sections` 会**删掉没被引用的 ISR** |
| 8 | 生成 `.bin` | `.bin` | —— |
| 9 | **校验**（向量表前两项 + 入口地址 + 尺寸） | 校验输出 | 烧进去才发现是坏的 |

⚠ 第 9 步是**最容易被跳过的一步**，也是本篇认为最该写进清单的一步——
见 [A.2](A.2-清单每步的实测数据.md) 的步骤 8。

## 二、第 1 步：内存布局先定死

```
STM32F103RB（NUCLEO-F103RB）
  Flash : 0x08000000, 128 KB
  RAM   : 0x20000000,  20 KB
  _estack = 0x20000000 + 20K = 0x20005000
```

⚠ **这个数字必须对**。实测里 `_estack` 被写进向量表第 0 项，
`app.bin` 的头 4 个字节就是 `00 50 00 20`（小端 = `0x20005000`）——
**上电第一件事就是把它装进 SP**，写错就是栈落在 Flash 里。

## 三、第 2 步：链接脚本的两个必写项

```ld
ENTRY(Reset_Handler)                     /* ⭐ 不写：ELF 入口变 0x0，只给 warning */
MEMORY { FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 128K
         RAM  (rwx) : ORIGIN = 0x20000000, LENGTH =  20K }
_estack = ORIGIN(RAM) + LENGTH(RAM);
SECTIONS {
  .vectors : { KEEP(*(.vectors)) } > FLASH   /* ⭐ 不写 KEEP：向量表被 gc 删掉 */
  .text    : { *(.text*) *(.rodata*) } > FLASH
  .data    : AT(_sidata) { _sdata = .; *(.data*) _edata = .; } > RAM
  .bss     : { _sbss = .; *(.bss*)  _ebss = .; } > RAM
  _sidata = LOADADDR(.data);
}
```

实测证据（两个必写项各自独立）：

| 漏掉 | 结果 |
|---|---|
| 漏 `ENTRY(Reset_Handler)` | `ld.lld: warning: cannot find entry symbol _start` → **ELF 入口 = `0x0`**；加回后 `0x8000015` |
| 漏 `KEEP` | `g_vectors` **从符号表里消失**，尺寸 226 → **206 B**，入口变 `0x8000001` |

⚠ 两者都**不报错**，只给 warning 或者干脆静默——这就是必须写进清单的原因。

（本仓库 `stm32/00-toolchain-clang/linker.ld` 第 10 行、
`stm32/01-bare-metal/linker.ld` 第 12 行都有 `ENTRY(Reset_Handler)`，
`Makefile` 里也有 `check-lds` / `check-nokeep` 目标专门检查这两项。）

## 四、第 3/4 步：启动文件必须做的三件事

```c
void Reset_Handler(void){
    unsigned long *src=&_sidata, *dst=&_sdata;
    while (dst < &_edata) *dst++ = *src++;       /* ① 把 .data 初值从 Flash 搬到 RAM */
    for (dst=&_sbss; dst < &_ebss;) *dst++ = 0;  /* ② 把 .bss 清零 */
    main();                                       /* ③ 进 main */
    for(;;){}
}
```

⚠ **全局变量不是"生来就有初值"的**——
`uint32_t g_init = 0x1234;` 的初值存在 **Flash** 里（`.data` 的加载地址 `_sidata`），
运行时地址却在 RAM。不搬，读到的就是上电随机值。

实测：不搬 `.data`/不清 `.bss` 的版本**照样能链接成功**（`text 72 / data 20 / bss 8 = 100 B`），
符号表看着也正常（`g_init` 在 `0x20000000`、`g_zero` 在 `0x20000004`）——
**链接器一点都不会提醒你**。

## 坑点

| 坑 | 原书怎么说 | 实际是什么（实测） |
|---|---|---|
| "新建工程向导会帮你准备好一切" | 附录给清单 | ⚠ 本仓库用 clang + `ld.lld`，**没有向导**；9 步全手工，每步漏了都静默 |
| "链接脚本写个 `SECTIONS` 就行" | —— | ❌ 实测漏 `ENTRY` → 入口 `0x0`（只 warning）；漏 `KEEP` → **向量表被删**（226→206 B） |
| "全局变量会自动初始化" | —— | ❌ 靠 `Reset_Handler` 搬 `.data`、清 `.bss`；不搬**链接照样成功** |
| "编译能过就是对的" | —— | ❌ 实测：漏 `-mthumb`、漏 `-mcpu` **都不报错**（`armv7m-none-eabi` target 已隐含 Thumb） |
| "`--gc-sections` 只是省空间" | —— | ⚠ 它会**删掉没被引用的 ISR**（[19.3](../19-systick-and-timer/19.3-g_ms与回绕安全的时间比较.md) 实测 `SysTick_Handler` 消失） |

## 衔接

- **下一篇**：[A.2 清单每步的实测数据](A.2-清单每步的实测数据.md)。
- **失败手册**：[A.3 做错会怎样](A.3-做错会怎样.md)。
- **实操**：[`stm32/01-bare-metal`](../../stm32/01-bare-metal/README.md) 是这份清单的完整版落地。
- **链接器**：[11 链接器](../11-linker/README.md) 把 `linker.ld` 逐行展开。

## 代码自测

<details>
<summary>Q1：为什么清单里要专门列"校验"这一步？</summary>

因为**前面的每一步漏了都不会报错**。实测四个例子：

| 漏掉的东西 | 链接器的反应 |
|---|---|
| `ENTRY(Reset_Handler)` | 一条 **warning**，产物照出 |
| `KEEP(*(.vectors))` | **什么都没有**，向量表静默消失 |
| 不搬 `.data` / 不清 `.bss` | **什么都没有**，链接成功 |
| 向量表不写 ISR | **什么都没有**，ISR 被 gc（[19.3](../19-systick-and-timer/19.3-g_ms与回绕安全的时间比较.md)） |

**四件事里三件是静默的。** 唯一会说话的那件（漏 `ENTRY`）说的还是 warning，
而 warning 在长输出里很容易被忽略。

所以校验这一步不是"锦上添花"，是**唯一能拦住这些错误的环节**。
最低限度的三项校验（都有实测脚本，见 [A.2](A.2-清单每步的实测数据.md) 步骤 8）：

```sh
# ① 向量表第 0 项 = SP，必须落在 RAM 区间内
# ② 向量表第 1 项 = Reset_Handler，必须为奇数（Thumb 标志）且落在 Flash
# ③ ELF 入口地址 ≠ 0
```

⚠ 这三项**只花几秒**，但能拦住本篇列出的大部分失败模式。
本仓库 `stm32/01-bare-metal` 里的 `check_vectors.py` + `make check-lds`
就是把它们固化成自动化检查。
</details>

<details>
<summary>Q2：附录这种"一页纸"的内容，值得单独写笔记吗？</summary>

**值得，而且它可能是全书最常用的一页。**

技术章节讲的是"某个机制怎么工作"，你**理解了之后就不会再翻**；
清单讲的是"每次开工都要走一遍的流程"，你**每次新建项目都要翻**。

本仓库的现状正好说明这点：

| 内容 | 状态 |
|---|---|
| ch11 链接器 | 已拆 6 篇，理解了就不再翻 |
| **建项目的 9 步** | ⚠ **每次新建目录都要重走一遍**，而且我实测发现**漏了 4 处都不报错** |

更关键的是：清单是**唯一会被"实际执行"检验的内容**。
写技术笔记时"我以为我懂了"可以混过去；
写清单时"我照着做了一遍"是硬判据——
**做不完就是没写完。**

⚠ 反过来，清单也最容易**过时**：工具换版本、路径变了、某个 flag 改名了，
清单就废了。所以本篇每条都附上**实测命令**，
下次照着跑一遍就知道还成不成立——**清单要能自证。**
</details>

<details>
<summary>Q3：我照着这份清单建了个项目，链接时 warning 说找不到 _start，要紧吗？</summary>

**要紧，但 `.bin` 可能照样能用——这正是它危险的地方。**

实测对照：

```
漏 ENTRY(Reset_Handler):
  ld.lld: warning: cannot find entry symbol _start; not setting start address
  Entry point address: 0x0                  ← ⚠

加上 ENTRY(Reset_Handler):
  （无警告）
  Entry point address: 0x8000015            ← ✅
```

**为什么 `.bin` 没事**：`llvm-objcopy -O binary` 是按**地址**把段抽出来拼的，
不看 ELF 头里的 entry 字段。而芯片上电也是读 `0x08000000` 的头两个字
（SP + Reset_Handler），**同样不看 entry**。

**那什么时候出事**：

| 场景 | 后果 |
|---|---|
| `openocd` / 调试器按 ELF 入口下断点 | 跳到 `0x0`，**断不到 `Reset_Handler`** |
| 某些烧录工具校验 ELF 头 | 直接拒绝烧录 |
| `objdump -d` 从入口开始反汇编 | 输出为空/错乱 |
| 有人后来加了 `ENTRY` 但写错符号名 | 入口指向别的函数，**不看 warning 根本发现不了** |

**对策**：链接脚本第一行就写 `ENTRY(Reset_Handler)`，
并且把"入口地址 ≠ 0"加进校验脚本。
**别习惯性地忽略 warning**——裸机上的 warning 经常是"链接器在告诉你它没看懂你的意图"。
</details>
