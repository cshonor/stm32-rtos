# 第 17 章 模块化编程 —— 章节导航

> 书：第 17 章 模块化编程（原书 p227–239）
> 对应实验：主机侧实测（clang 23.1.0 / macOS arm64 + `ar` / `llvm-ar` 23.1.0）
> + **裸机真链接**（`--target=armv7m-none-eabi -mcpu=cortex-m3` + `ld.lld` 23.1.0 + 本仓库 `linker.ld`）

## 这一章在讲什么

**C 没有 `namespace`、`class`、`module` 关键字，
但 Linux 内核、FreeRTOS、Zephyr 这些超大型 C 项目照样组织得很好——
靠的就是本章这三样：**

1. **命名空间约定**：`static` 隐藏内部 + 统一前缀（17.02）；
2. **静态库**：`ar` 打包 `.o`，链接时**按需抽取**（17.03–17.05）；
3. **弱符号**：库提供默认实现，使用者可以覆盖（17.06）——
   **这一条在裸机上早就在用了**（ch03 的 `Default_Handler` 就是）。

一句话概括全章：

> **本章是"工程化"章：前 16 章教语言特性，本章教怎么把它们组织成大型项目。
> 对裸机尤其重要——Flash 只有 64 KB，按需抽取和弱符号是省代码的核心手段。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 17.01 | 模块设计 | [17.01-模块设计](17.01-模块设计.md) |
| 17.02 | 命名空间 | [17.02-命名空间](17.02-命名空间.md) |
| 17.03 | 库 | [17.03-库](17.03-库.md) |
| 17.04 | ranlib 与库链接 | [17.04-ranlib与库链接](17.04-ranlib与库链接.md) |
| 17.05 | 确定性与不确定性库 | [17.05-确定性与不确定性库](17.05-确定性与不确定性库.md) |
| 17.06 | 弱符号 | [17.06-弱符号](17.06-弱符号.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p227–239），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（**17.01–17.06**）；
> 顶层索引原先写的 `17.01–17.7` 是错的，已订正为 **17.01–17.06**。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 17.1 讲模块设计 | 给出**客观指标**：实测 `leaky.o` 泄漏 **3 个**外部符号 vs `clean.o` 只有 **1 个**；⚠ 实测 `static inline` 放头文件在 **`-O0` 下每个 `.c` 各生成一份**（`-O1` 才是 0 份）；完整检查清单 + 反面例子 |
| 17.2 讲命名空间 | ⚠ 实测**不加 `static` 会 duplicate symbol**（两个 `rx_count`）；四种同名组合全测（弱/强/强强/弱弱）；⚠ **ISR 名字不能加前缀**（向量表是硬件约定）；⚠ 不要用 `_` 开头（保留标识符） |
| 17.3 讲库 | ⭐ **核心实测：抽取粒度是 `.o` 级不是函数级**——两个成员时 `mul` 完全不进镜像；同一 `.o` 时 **`mul` 被带进来**；裸机实测 `--gc-sections` 把 `mul`（**4 字节**）丢掉（text 56 → 52）；`--print-gc-sections` 看到底丢了什么 |
| 17.4 讲 ranlib | ✅ 实测 `ar rcs` 已包含索引（`__.SYMDEF SORTED`）；⚠ **macOS `ar` 对 ELF 成员建不出索引**（实测 "table of contents is empty" 警告），要用 **`llvm-ar`**；给出裸机完整链接命令 |
| 17.5 讲确定性 | ⚠ **修正了课本说法**：实测 **ld.lld 23.1.0 库放前面也能过且完全静默**，要 `--warn-backrefs` 才报 `backward reference detected`；⚠ GNU ld 的经典失败行为**本机未实测**（本机没有 GNU ld）；⚠ **真正的"不确定性"是多库同名符号**：不报错，谁在前抽谁，**换顺序行为就变** |
| 17.6 讲弱符号 | ⭐ **裸机实测默认 ISR**：4 个 ISR 全是 `W` 且地址都在 `0x08000018`；提供一个强定义后 `EXTI0_IRQHandler` 变 `T` 且地址变 `0x0800002c`，**其余三个不动**；⚠ **弱未定义符号的平台差异实测**：lld ✅ 解析成 0（`w opt_hook`），**macOS ld64 ❌ 直接 `Undefined symbols`** |
| 书里没提 | 本仓库取向：模块内部一律 `static` + `模块__` 双下划线；公开接口统一前缀；ISR 是唯一必须污染全局命名空间的地方 |

## 核心实测数据（本章的锚点）

```
① 模块干不干净，看符号表（clang -O1 -c + llvm-nm）
--- leaky.o（漏）---            --- clean.o（干净）---
T _api_get                      T _api_get          ← ✅ 只有这一个
T _helper_sum   ← ⚠ 内部函数     （以下都是小写 = 本地）
S _rx_count     ← ⚠ 内部状态     b _s_rx_count
外部可见符号数：leaky.o = 3   |   clean.o = 1

② static inline 放头文件（两个 .c 都 include hdr.h）
-O0：use1.o 有 t _inl_add，use2.o 也有 t _inl_add   ← ⚠ 两份
-O1：use1.o 0 个，use2.o 0 个                        ← ✅ 内联掉

③ ⭐ 静态库的抽取粒度（主机，只用了 add）
libmymath.a（add.o + mul.o 两个成员）→ 镜像里只有 _add     ✅
libmath1.a（mymath.o 含两个函数）    → 镜像里 _add + _mul  ⚠

④ ⭐ 裸机：--gc-sections 细化到函数级（M3 + linker.ld，libmath1.a）
关闭 gc-sections: text 56  data 8  bss 4  |  add/mul: 08000030 T add  08000034 T mul
开启 gc-sections: text 52  data 8  bss 4  |  add/mul: 0800002e T add
   → mul 占 4 字节
$ ld.lld --print-gc-sections
removing unused section ./libmath1.a(bmath.o):(.text.mul)
removing unused section ./libmath1.a(bmath.o):(.ARM.exidx.text.mul)

⑤ 建库与索引
$ ar rcs libmymath.a add.o mul.o && ar -t libmymath.a
__.SYMDEF SORTED          ← 索引（现代 ar rcs 已包含，不用单独 ranlib）
add.o
mul.o
$ llvm-nm libmymath.a
add.o: 0000000000000000 T _add
mul.o: 0000000000000000 T _mul

⑥ ⚠ macOS ar 对 ELF 成员建不出索引（交叉编译的坑）
$ ar rcs libdrv.a badd.o bmul.o
warning: .../arm64-apple-darwin20.0.0-ranlib: archive library: libdrv.a
         the table of contents is empty
         (no object file members in the library define global symbols)
$ llvm-ar rcs libdrv.a badd.o bmul.o && llvm-ar -t libdrv.a
badd.o
bmul.o                    ← ✅ 无警告（格式无关）
⚠ 索引为空时链接仍成功（lld 退化成全扫描），只是变慢 → 坑很隐蔽

⑦ ⚠ 库的顺序（裸机 ld.lld 23.1.0）
正确顺序  bvec.o bapp.o -L. -ldrv                    → ✅ 成功  text 52 data 8 bss 4
错误顺序  -L. -ldrv bvec.o bapp.o                    → ✅ 也成功（完全静默！）
加 --warn-backrefs：
  ld.lld: warning: backward reference detected:
          add in bapp.o refers to ./libdrv.a(badd.o)
--start-group -L. -ldrv --end-group                  → ✅ 也成功，大小一致
⚠ GNU ld 的"undefined reference"是教科书说法，本机无 GNU ld，未实测

⑧ 符号冲突的四种组合（主机实测）
一个弱，没人覆盖   → board_id() = 0
一个弱 + 一个强    → board_id() = 103     ✅ 强赢
两个弱            → board_id() = 0       ⚠ 选第一个，不确定
两个强            → duplicate symbol '_board_id'  ❌
两个 .o 同名全局   → duplicate symbol '_rx_count'  ❌

⑨ ⭐ 裸机弱别名默认 ISR（llvm-nm）
① 没人覆盖：
08000018 T Default_Handler
08000018 W EXTI0_IRQHandler      08000018 W HardFault_Handler
08000018 W NMI_Handler           08000018 W USART1_IRQHandler
0800001c T Reset_Handler
② 提供一个强定义 EXTI0_IRQHandler：
08000018 T Default_Handler
0800002c T EXTI0_IRQHandler      ← ⚠ 变 T（强），地址也变了
08000018 W HardFault_Handler     ← 其余三个没动
08000018 W NMI_Handler          08000018 W USART1_IRQHandler

⑩ ⚠ 弱【未定义】符号的平台差异
ld.lld（armv7m 裸机）：✅ 链接成功，w opt_hook 解析成 0（text 36 data 0 bss 4）
macOS ld64：           ❌ Undefined symbols for architecture arm64: _opt_hook
⚠ nm 大小写：W = 弱定义（有地址），w = 弱未定义（无地址）
```

## 读完本章你应该能回答

- 怎么客观判断一个模块写得好不好？（看 `.o` 泄漏多少符号：实测 **3 vs 1**）
- `static inline` 放头文件会占几份 Flash？（⚠ **`-O0` 下 N 份**，`-O1` 下 0 份）
- 寄存器地址宏应该放头文件还是 `.c`？（**.c**，否则换板子要改契约）
- 为什么要"用函数读状态"而不是暴露全局变量？（封装 + 防误写 + 原子性）
- `static` 到底做了什么？（把链接属性从 external 改成 internal）
- 不加 `static` 会怎样？（实测 **duplicate symbol**）
- 为什么 ISR 名字不能加前缀？（向量表里是**硬件约定**的符号名）
- 两个弱定义同名会怎样？（⚠ **不报错，选第一个**——不确定）
- 静态库的抽取粒度是什么？（**`.o` 成员级**，不是函数级）
- 怎么把粒度细化到函数级？（`-ffunction-sections -fdata-sections` + `--gc-sections`；实测 `mul` 省 **4 B**）
- 什么会破坏 GC？（`KEEP()`、`.init_array`/constructor、被引用的弱符号）
- 裸机上有动态库吗？（**没有**，只有静态库）
- `ranlib` 现在还要手动跑吗？（不用，`ar rcs` 的 `s` 已包含）
- 交叉编译时建库该用什么工具？（⚠ **`llvm-ar`**；macOS `ar` 对 ELF 建不出索引）
- 库放在命令行前面一定会失败吗？（⚠ **ld.lld 实测能过且静默**，要 `--warn-backrefs` 才报）
- 循环依赖怎么解？（`--start-group/--end-group`，实测成功）
- 两个库有同名符号会报错吗？（⚠ **不报错**，谁在前抽谁，换顺序行为就变）
- 弱符号在裸机上最经典的用法是什么？（**默认 ISR**，实测 4 个 `W` 同地址）
- `W` 和 `w` 在 `nm` 里的区别？（`W` = 弱定义有地址，`w` = 弱未定义）
- 弱未定义符号在 macOS 上能过吗？（❌ **不能**，实测 `Undefined symbols`）
- 弱符号能省 Flash 吗？（能：多个 ISR 共用一个默认实现；但被引用时会把实现拉进来）

## 前置 / 后续

- 前置：[第 3 章 裸机系统编程](../03-embedded-system-programming/README.md)（`Default_Handler`、向量表）、
  [第 7 章 栈帧](../07-stack-frame-functions/README.md)（栈预算）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（函数指针 = 另一种接口与实现分离）、
  [第 10 章 中断](../10-interrupts/README.md)（ISR 命名与可重入）、
  [第 11 章 链接器](../11-linker/README.md)（`--gc-sections`、`KEEP()`、map 文件）、
  [第 12 章 预处理器](../12-preprocessor/README.md)（include guard 撞名的实测）
- 后续：[第 18 章 后记](../18-next-steps/README.md)
- **LDD- / RTOS 侧**：
  - 内核的 `EXPORT_SYMBOL` / `EXPORT_SYMBOL_GPL` 就是"显式导出"版的命名空间管理；
  - 内核的 `__weak` 修饰符、以及"驱动 core 提供框架 + 具体驱动实现回调"
    （`struct file_operations`）就是本章机制的规模化；
  - **FreeRTOS 的 `vApplicationStackOverflowHook` / `vApplicationIdleHook`
    都是弱符号钩子**——"可选功能"全靠这个机制；
  - Zephyr 的 `Kconfig` + `devicetree` 是"编译期决定模块组合"的工业化版本，
    解决的问题和静态库按需抽取同源：**不让没用到的代码进镜像**。

## 实验复现

```sh
# ① 模块泄漏检测
clang -O1 -c leaky.c -o leaky.o && llvm-nm leaky.o
clang -O1 -c clean.c -o clean.o && llvm-nm clean.o

# ② static inline 的份数
clang -O0 -c use1.c -o u1.o && llvm-nm u1.o | grep inl
clang -O1 -c use1.c -o u1b.o && llvm-nm u1b.o | grep inl

# ③ 静态库抽取粒度（主机）
clang -O1 -c add.c -o add.o && clang -O1 -c mul.c -o mul.o
ar rcs libmymath.a add.o mul.o && ar -t libmymath.a && llvm-nm libmymath.a
clang -O1 -o app main17.c -L. -lmymath && llvm-nm app | grep -E "_add|_mul"

# ④ 裸机：gc-sections 细化到函数级
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib \
      -ffunction-sections -fdata-sections -c bmath.c -o bmath.o
llvm-ar rcs libmath1.a bmath.o
ld.lld -T linker.ld           -o nogc.elf   bvec.o bapp.o -L. -lmath1   # text 56
ld.lld -T linker.ld --gc-sections -o withgc.elf bvec.o bapp.o -L. -lmath1 # text 52
ld.lld -T linker.ld --gc-sections --print-gc-sections -o pgc.elf ...

# ⑤ ⚠ macOS ar 对 ELF 的索引问题
ar rcs libdrv.a badd.o bmul.o        # ← 有警告
llvm-ar rcs libdrv.a badd.o bmul.o   # ← 干净

# ⑥ 库顺序 + --warn-backrefs
ld.lld -T linker.ld --gc-sections            -o ok.elf  bvec.o bapp.o -L. -ldrv
ld.lld -T linker.ld --gc-sections            -o bad.elf -L. -ldrv bvec.o bapp.o
ld.lld -T linker.ld --gc-sections --warn-backrefs -o bad2.elf -L. -ldrv bvec.o bapp.o
ld.lld -T linker.ld --gc-sections -o grp.elf bvec.o bapp.o --start-group -L. -ldrv --end-group

# ⑦ 弱符号（主机）
clang -O1 -o w1 weak_demo.c && ./w1                      # 0
clang -O1 -o w2 weak_demo.c override.c && ./w2           # 103
clang -O1 -o w3 weak_demo.c weak2.c && ./w3              # 0（两个弱，选第一个）
clang -O1 -o w5 weak_demo.c override.c override2.c       # duplicate symbol

# ⑧ 裸机弱别名默认 ISR
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib \
      -ffunction-sections -fdata-sections -c startup.c -o startup.o
ld.lld -T linker.ld -o s1.elf startup.o main_weak.o            # 四个 W 同地址
ld.lld -T linker.ld -o s2.elf startup.o main_weak.o my_isr.o   # EXTI0 变 T
```

⚠ **本机环境限制（诚实标注）**：

1. **没有 GNU ld**：本机只有 `ld.lld` 23.1.0 和 macOS `ld64`。
   "GNU ld 库放前面会 undefined reference"是**教科书说法，本机未实测**；
   实测到的是 lld **能过且静默**（需 `--warn-backrefs` 才报警）。
2. **macOS `ar` 无法索引 ELF 成员**（实测警告），交叉编译一律用 `llvm-ar`。
3. **macOS ld64 不支持弱未定义符号**（实测 `Undefined symbols`），
   所以"弱钩子 + 判空"的写法在 macOS 上链接失败。
