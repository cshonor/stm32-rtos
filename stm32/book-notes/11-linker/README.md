# 第 11 章 链接器 —— 章节导航

> 书：第 11 章 链接器（原书 p154–173）
> 对应实验：`ld.lld -T linker.ld -Map=blink.map --gc-sections` 真链接
> （目标 `--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding`，clang 23.1.0）
> 产物：`blink.elf` / `blink.map` / `blink.bin`，以及 KEEP / ASSERT / gc / 自定义段四组对照实验

## 这一章在讲什么

**这是本书最值钱的一章。** 前 10 章的内容任何一本 C 书都有，
**"链接脚本怎么写"只有嵌入式书才讲**。

前 10 章里，链接器一直是幕后那个"把 `.o` 拼成可执行文件"的东西。
第 11 章第一次把它拉到台前，讲四件事：

1. **内存模型**：VMA / LMA 的区别（`.data` 的"双重身份"）；
2. **链接器定义符号**：`_sdata` / `_edata` / `_sbss` / `_ebss` / `_estack` 从哪来；
3. **重定位**：`0x08000013` 这个数是怎么算出来的；
4. **怎么读 map 文件**（回答"程序多大、放哪、谁被丢了"的唯一权威）；
5. **高级用法**：Flash 当"永久存储"、多配置、定制实例、固件升级。

一句话概括全章：

> **在 PC 上，"代码放哪"由内核决定（ELF loader + mmap）；
> 在裸机上，由你写的链接脚本决定——而且没人替你检查。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 11.1 | 编译和链接的内存模型 | [11.1-编译和链接的内存模型](11.1-编译和链接的内存模型.md) |
| 11.2 | 链接过程 | [11.2-链接过程](11.2-链接过程.md) |
| 11.3 | 链接器定义的符号 | [11.3-链接器定义的符号](11.3-链接器定义的符号.md) |
| 11.4 | 重定位 | [11.4-重定位.md](11.4-重定位.md) |
| 11.5 | 映射文件 | [11.5-映射文件](11.5-映射文件.md) |
| 11.6 | 高级用法 | [11.6-高级用法](11.6-高级用法.md) |

11.6 含四个子节（原书以 11.6.x 形式给出），合并在一篇里：

| 子节 | 在 11.6 里的位置 |
|---|---|
| "永久"存储的闪存 | 一、 |
| 多配置项 | 二、 |
| 定制实例 | 三、 |
| 固件升级 | 四、 |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p154–173），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（11.1–11.6）；
> 顶层索引原先写的 `11.1–11.9` 是错的，已订正为 **11.1–11.6**。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 11.1 讲内存模型 | 实测真链接：`.data` **VMA `0x20000000` / LMA `0x08000084`**；`.bss` 是 **NOBITS**；`blink.bin = 136 B = 132(text) + 4(data 副本)`，`.bss` 不在 bin 里 |
| 11.2 讲链接过程 | 做了**失败实验**：去掉 `KEEP` → `g_vectors` 从符号表消失；RAM 改成 512 → `ld.lld: error: RAM 不够：栈至少要 512 字节` |
| 11.3 讲链接器定义符号 | 实测 `llvm-nm -n --print-size` 逐个打印；指出 `_sidata = LOADADDR(.data)` 写成 `. = .` 是**错的**（拿的是 VMA） |
| 11.4 讲重定位 | **三方对照打脸**：map `0x08000013` / `llvm-nm` `0x08000012` / 向量表字节 `13000008`；讲清 `$t`/`$d` 映射符号与 Thumb 位 |
| 11.5 讲怎么读 map | 补上书没讲的：**`--gc-sections` 单独用没用**（实测 134/8 → 134/8，必须配 `-ffunction-sections`）；**lld 的 map 不列丢弃段**，要 `--print-gc-sections` |
| 11.6 讲高级用法 | 实测三个坑：① 非 `const` 变量放 Flash 段 → 生成 `str` 写 Flash 且**链接器不报错**；② 配置区钉死在最后一页 → `.bin` 从 136 B 变 **130060 B**；③ bootloader 跳转时向量表里的地址**已经是奇数**，不要再 `\| 1` |
| 书里没提 | `(rx)` 只是提示，**lld 不检查**；`objcopy -O binary` 会**填满地址空洞**；`--only-section` / `--remove-section` 拆配置区 |

## 核心实测数据（本章的锚点）

```
① 真链接产物（blink.elf，ld.lld -T linker.ld -Map=blink.map）
llvm-size：   text 132   data 4   bss 4
.map：        .isr_vector VMA=LMA=08000000  size 10 (=16)
              .text       VMA=LMA=08000010  size 74 (=116)
              .data       VMA=20000000 LMA=08000084  size 4   ← VMA/LMA 分离
              .bss        VMA=20000004 LMA=20000004  size 4   ← NOBITS
llvm-readelf -S：.bss 的 Type = NOBITS
llvm-objcopy -O binary → blink.bin = 136 B = 132 + 4（.bss 不算）

② 链接器定义符号（llvm-nm -n --print-size blink.elf）
_sidata 08000084 A      ← LOADADDR(.data)，在 Flash
_sdata  20000000 D      _edata  20000004 D
_sbss   20000004 B      _ebss   20000008 B
_estack 20005000 A      ← ORIGIN(RAM) + LENGTH(RAM)

③ 重定位三方对照（同一个 Reset_Handler）
map 文件：        0x08000013    ← 奇（原始符号值，带 Thumb 位）
llvm-nm：         0x08000012    ← 偶（llvm 主动清 bit0）
向量表实际字节：   0x08000013    ← 奇（13000008，小端）
$ llvm-objdump -s -j .isr_vector
 8000000  00500020 13000008 11000008 11000008
          └ _estack=0x20005000   └ Reset_Handler

④ KEEP 实验（去掉 KEEP 会怎样）
有 KEEP：08000000 R g_vectors
无 KEEP：g_vectors 从符号表消失（向量表没了，硬件读不到入口）

⑤ ASSERT 实验
RAM LENGTH = 512：ld.lld: error: RAM 不够：栈至少要 512 字节
RAM LENGTH = 20K：链接成功

⑥ --gc-sections 到底有没有用（gc.c 含死代码 dead_fn + g_dead）
粗分节 + 无 gc：  text 134  data 8
粗分节 + gc：     text 134  data 8     ← ⚠ 没变化
细分节 + 无 gc：  text 134  data 8
细分节 + gc：     text 122  data 4     ← ✅ text −12（dead_fn 8 + live_fn 4），data −4
$ ld.lld ... --gc-sections --print-gc-sections
removing unused section gcs.o:(.text.dead_fn)
removing unused section gcs.o:(.data.g_dead)

⑦ 自定义 .persistent 段（放 Flash）
 800007c  800007c        c     4 .persistent
 800007c  800007c        c     1                 g_cfg
llvm-nm：0800007c R g_cfg / 08000084 R _epersist   ← 'R' = 只读
llvm-objdump -s -j .persistent：bebafeca 00000000 00000000

⑧ 非 const 放 Flash 段（坑）
llvm-nm：  08000088 D g_counter      ← 'D' 不是 'R'
readelf：  .persistent  ... WA       ← 可写
反汇编：   str r1, [r0]              ← 往 0x08000088（Flash）写
链接器：   无警告、无错误

⑨ 配置区布局对 .bin 的影响
紧跟 .text：            persist2.bin =     136 B
钉死 0x0801FC00：       persist.bin  =  130060 B（0x0801FC0C，空洞填 0）
--only-section 抽出：   cfg.bin      =       8 B（39300000 00c20100 = 12345 / 115200）

⑩ bootloader app（只改 ORIGIN 一行）
           原版             app 版（ORIGIN=0x08004000）
g_vectors  0x08000000       0x08004000
Reset_Hdl  0x08000012(nm)   0x0800402a(nm)
向量表字节 13000008         2b400008 = 0x0800402b（奇数）
```

## 读完本章你应该能回答

- VMA 和 LMA 有什么区别？哪个段两者不同？
- `.bss` 为什么不占 Flash？（NOBITS）
- `blink.bin` 是 136 字节，而 `.bss` 有 4 字节，为什么不算进去？
- `KEEP` 和 `__attribute__((used))` 各管哪一关？
- `ASSERT` 把什么运行时问题前移到了链接期？
- `_sidata` 为什么是 `LOADADDR(.data)` 而不是 `. = .`？
- 为什么 `llvm-nm` 和 map 里的地址差 1？（Thumb 位）
- `$t` / `$d` 是什么？看到 `$d` 后面的 `.word` 该当成什么？
- 想算 Flash 用了多少，用 `llvm-size` 的哪一列？要不要加 `data`？
- 为什么开了 `--gc-sections` 死代码还在一个字节没少？
- 怎么看"哪些段被丢了"？map 里有吗？
- 放 Flash 的变量为什么必须 `const`？不加会怎样？链接器会拦吗？
- 把配置区钉在最后一页，`.bin` 会变成多大？怎么解决？
- bootloader 跳 app，链接脚本改什么？`| 1` 要不要加？

## 前置 / 后续

- 前置：[第 1 章 Hello World](../01-hello-world/README.md)（`used` vs `KEEP` 的第一课）、
  [第 3 章 嵌入式系统编程](../03-embedded-system-programming/README.md)（向量表、启动代码实测）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（函数指针与 Thumb 位）、
  [第 9 章 串口](../09-uart-serial/README.md)（`llvm-size` / `-fstack-usage` 的用法）、
  [第 10 章 中断](../10-interrupts/README.md)（栈预算、`.bss` 里的环形缓冲）
- 后续：第 12 章起（预处理器等）依赖本章的地址观：
  **任何"这个变量在哪"的问题，答案都在 map 文件里。**
- **LDD- 侧**：Linux 内核模块的 `.init.text` / `__initdata` 用完即弃，
  就是本章 `.data` 的 LMA/VMA 分离思路的放大版；
  `vmlinux.lds.S` 是同一套语法的巨型版本；
  `MODPOST` 报的 `Section mismatch` 就是"段放错了区域"的静态检查——
  **裸机上没有这个检查，所以坑都是静默的。**

## 实验复现

```sh
# 交叉编译（clang 23.1.0，在本仓库的 cdev 环境里）
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os \
      -c startup.c -o startup.o
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os \
      -c main.c -o main.o

# 链接（带 map，带 gc）
ld.lld -T linker.ld -e Reset_Handler --gc-sections --print-gc-sections \
       -Map=blink.map main.o startup.o -o blink.elf

# 三件套查看
llvm-size blink.elf
llvm-nm -n --print-size blink.elf
llvm-readelf -S -W blink.elf
llvm-objdump -s -j .isr_vector blink.elf
llvm-objcopy -O binary blink.elf blink.bin && ls -l blink.bin
```

⚠ **lld 会警告** `cannot find entry symbol _start`——
裸机没有 `_start`，用 `-e Reset_Handler` 指定入口即可（不影响链接结果）。
