# 第 13 章 动态内存 —— 章节导航

> 书：第 13 章 动态内存（原书 p189–201）
> 对应实验：主机侧运行实测（clang 23.1.0 / macOS arm64 / Apple Silicon）
> + Cortex-M3 交叉（`-ffreestanding`）裸机侧对照

## 这一章在讲什么

**书从这里进入第二部分"用于大型机器的 C 语言编程"——
这一整部分都跑在你的电脑上，不在板子上。**

所以本章的结构是**两侧对照**：

- **主机侧**：`malloc`/`free`、链表、Valgrind、ASan——**工具齐全**；
- **裸机侧**：**这些全都没有**，要用内存池和静态分配替代。

一句话概括全章：

> **裸机上不是"`malloc` 有风险"，而是"`malloc` 根本不存在"——
> 实测链接就失败（`ld.lld: error: undefined symbol: malloc`）。
> 所以本章的真实价值是：学会在主机上把内存问题查干净，
> 再回到裸机上用"可预测"的方案绕开它们。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 13.1 | 基本堆分配和释放 | [13.1-基本堆分配和释放](13.1-基本堆分配和释放.md) |
| 13.2 | 链表 | [13.2-链表](13.2-链表.md) |
| 13.3 | Valgrind | [13.3-Valgrind](13.3-Valgrind.md) ⚠ **本机未安装，未实测** |
| 13.4 | GCC AddressSanitizer | [13.4-GCC-AddressSanitizer](13.4-GCC-AddressSanitizer.md) ✅ 全部实测 |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p189–201），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（13.1–13.4）；
> 顶层索引原先写的 `13.1–13.6` 是错的，已订正为 **13.1–13.4**。

## ⚠ 关于 13.3 的诚实声明

**Valgrind 在这台 Mac 上没有安装，且装不上**（无 root 权限）。

```
$ which valgrind
valgrind not found
```

所以 [13.3](13.3-Valgrind.md) 的内容是"机制说明 + 与 ASan 的对比 + 命令参考"，
**不是实测**。所有标记"实测"的数据都在 [13.4](13.4-GCC-AddressSanitizer.md)。

**但有一个实测发现让 Valgrind 变得必要**：
本机 macOS arm64 上，**ASan 的 LeakSanitizer 不报泄漏**
（`ASAN_OPTIONS=detect_leaks=1` 只打出 `checking for leaks`，1024 字节的泄漏没报出来）。
**查泄漏要靠 Linux 上的 Valgrind**（比如 Raspberry Pi 5 的 Debian 13）。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 13.1 讲 `malloc`/`free` | ⚠ 实测**裸机上链接直接失败**（`U malloc` → `ld.lld: error: undefined symbol: malloc`）；实测 `malloc` 耗时抖动 **平均 88 ns / 最坏 18 µs**；给出内存池实测（text 140 B、`pool_alloc` 40 B、零依赖），并实测 `used` 字段类型导致的**对齐坑**（`offsetof(data)` 1 vs 4） |
| 13.2 讲链表 | ⚠ 实测动态链表**每节点 18.2 B vs 静态池 16.0 B**（+14%），且**节点不连续**（间距出现 −2048 / +2176）；指出"用下标代替指针省 RAM"**在 32 位裸机上不成立** |
| 13.3 讲 Valgrind | ⚠ **本机未安装，未实测**。改为：机制对比（运行时二进制翻译 vs 编译期插桩）+ 命令参考 + 输出解读 + 与 ASan 的取舍表 |
| 13.4 讲 ASan | ✅ **全部实测**：堆溢出（"0 bytes after 40-byte region" 完整栈）、UAF、double free、**⚠ 只在 `-O0` 能抓到**（`-O1` 下 LLVM IR 的 malloc/free 调用数是 **0**）、**⚠ 本机 LSan 不报泄漏**；补上 UBSan（对齐检查对嵌入式特别有用） |
| 书里没提 | 优化器会"删掉 bug"给 ASan 假象；`malloc_good_size(24)` = 32 B（33% 浪费）；内存池块的对齐与 `_Static_assert` |

## 核心实测数据（本章的锚点）

```
① 裸跑：三处严重错误全部静默
$ clang -O1 -g -o h1 h1.c && ./h1
malloc(40) -> 0x142604b10
p[9]=9
越界写 p[10] 完成（heap overflow）      ← ① 堆溢出
free 后再用（use-after-free）: 0        ← ② UAF
结束（有一块 1024 字节没释放）          ← ③ 泄漏
退出码: 0                               ← ⚠ 一个警告都没有

② 裸机上根本没有 malloc
$ llvm-nm -u bm.o
         U free
         U malloc
$ ld.lld -T linker.ld -e main bm.o -o bm.elf
ld.lld: error: undefined symbol: malloc
ld.lld: error: undefined symbol: free

③ malloc 耗时抖动（主机侧）
固定 64 B（200 轮 × 2048 次）：
  min  80.6 ns   avg 106.5 ns   max 209.5 ns   max/min = 2.6x
随机 16..2016 B（204800 次）：
  min   0.0 ns   avg  87.7 ns   max 18000 ns   ← ⚠ 18 µs
（115200 串口的 ISR 预算是 8.7 µs —— 超了）

④ 内存池（Cortex-M3，-Os）
$ llvm-size pool.o       text 140   data 0   bss 532
$ llvm-nm -u pool.o      （空 = 零外部依赖）
$ llvm-nm --print-size -S pool.o
  00000000 00000028 T pool_alloc    ← 40 B
  00000000 0000001e T pool_free     ← 30 B
.bss 532 = 16 块 × 33 B (528) + g_out 4
（注：这份 pool.c 用的是 uint8_t used → sizeof=33，见 ⑤ 的对齐坑；
  改成 uint32_t used 后 sizeof=36，16 块 = 576）

⑤ ⚠ 内存池块的对齐坑
A{uint8_t  used; uint8_t data[32];}  sizeof=33  16块=528  offsetof(data)=1  ⚠ 非对齐
B{uint32_t used; uint8_t data[32];}  sizeof=36  16块=576  offsetof(data)=4  ✅
C 同上 + aligned(4)                  sizeof=36  16块=576

⑥ 链表：静态池 vs malloc
静态池  1000 节点：16000 B（1000 × sizeof=16，连续）
动态    1000 节点：地址跨度 18176 B → 每节点 18.2 B（+14%）
前 8 个节点地址间距：-624 -2048 16 2176 16 96 16 16   ← 负数 = 不连续
malloc_good_size：1→16  8→16  16→16  24→32（⚠ 33% 浪费）

⑦ ASan 抓堆溢出（-O1）
==44198==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x604000000438
WRITE of size 4 at 0x604000000438 thread T0
    #0 0x000104f93b30 in main h1.c:8
0x604000000438 is located 0 bytes after 40-byte region [0x604000000410,0x604000000438)
allocated by thread T0 here:
    #1 0x000104f93a30 in main h1.c:4
SUMMARY: AddressSanitizer: heap-buffer-overflow h1.c:8 in main
Shadow bytes around the buggy address:
=>0x604000000400: fa fa 00 00 00 00 00[fa]fa fa fa fa fa fa fa fa

⑧ ⚠ ASan 在 -O1 以上抓不到 double free
-O0：ERROR: AddressSanitizer: attempting double-free ... ABORTING（退出码 134）✅
-O1：（无输出）退出码 0 ❌
-O2：（无输出）退出码 0 ❌
原因（LLVM IR 里的 malloc|free 调用数）：
  -O0 → 3        -O1 → 0        ← 优化器做了 dead malloc elimination

⑨ ⚠ 本机 LeakSanitizer 不报泄漏
$ ./leaka                                    （无输出）rc=0
$ ASAN_OPTIONS=detect_leaks=1 ./leaka        （无输出）rc=0
$ ASAN_OPTIONS=detect_leaks=1:verbosity=1 ./leaka
==44282==LeakSanitizer: checking for leaks   ← 打了"在检查"，但 1024 B 没报出来

⑩ 环境事实
$ which valgrind        → valgrind not found（本节 13.3 未实测）
$ otool -L dbla | grep asan
	@rpath/libclang_rt.asan_osx_dynamic.dylib   ← ASan 要链接运行时库（裸机放不下）
```

## 读完本章你应该能回答

- 裸跑时堆溢出 / UAF / 泄漏会报吗？（实测：**全静默，退出码 0**）
- 裸机上为什么链接会失败？`malloc` 底下缺哪一层？（缺 `_sbrk` / 系统调用）
- `malloc` 的平均耗时和最坏耗时差多少？（88 ns vs 18 µs）
- 115200 串口的 ISR 预算是多少？`malloc` 能用吗？（8.7 µs，**超了**）
- 内存池为什么"无碎片 + 耗时有界"？（固定块大小）
- 自己写内存池，`used` 该用什么类型？为什么？（`uint32_t`；`uint8_t` 会让 `data` 落在偏移 1）
- 动态链表比静态池多占多少？（+14%，且节点不连续）
- "用数组下标代替指针省 RAM"对吗？（**32 位裸机上不成立**）
- `malloc_good_size(24)` 是多少？意味着什么？（32 B，33% 浪费）
- ASan 报的 "0 bytes after 40-byte region" 怎么读？
- 为什么 `-O1` 下 ASan 抓不到 double free？
- 本机上 ASan 能查泄漏吗？（**不能**）
- Valgrind 和 ASan 各自独有的能力是什么？
- 裸机上没有检错工具，怎么办？（四条路）

## 前置 / 后续

- 前置：[第 6 章 数组指针字符串](../06-arrays-pointers-strings/README.md)（数组 vs 链表的访问模式）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（结构体对齐、`offsetof`）、
  [第 10 章 中断](../10-interrupts/README.md)（ISR 预算、不可重入）、
  [第 11 章 链接器](../11-linker/README.md)（静态分配的总量在 map 里一目了然）
- 后续：第 14 章缓冲文件 I/O（又是主机侧的一章）
- **LDD- 侧**：内核的 `kmalloc` / `vmalloc` / slab / `kmem_cache`
  就是**内存池思想的内核版**：
  - slab 的"对象缓存" = 本章的固定块大小池；
  - `kmem_cache_create(name, size, align, ...)` 里的 **align 参数**
    正是 [13.1](13.1-基本堆分配和释放.md) 实测的对齐坑；
  - `GFP_ATOMIC`（不可睡眠）对应裸机"ISR 里不能分配"；
  - 内核的 `KASAN` 就是 ASan 的内核版（同样有 shadow memory 开销）。

## 实验复现

```sh
# ① 裸跑 vs ASan（主机侧）
clang -O1 -g          -o h1  h1.c && ./h1
clang -O1 -g -fsanitize=address -o h1a h1.c && ./h1a

# ② double free 的优化级陷阱
for o in -O0 -O1 -O2; do clang $o -g -fsanitize=address -o dbl_$o dbl.c && ./dbl_$o; echo "rc=$?"; done
clang -O0 -S -emit-llvm -o - dbl.c | grep -cE "call.*(malloc|free)"   # → 3
clang -O1 -S -emit-llvm -o - dbl.c | grep -cE "call.*(malloc|free)"   # → 0

# ③ 泄漏检测（本机实测无效，仅作对照）
ASAN_OPTIONS=detect_leaks=1:verbosity=1 ./leaka

# ④ 裸机侧：malloc 链接失败
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os -c bm.c -o bm.o
llvm-nm -u bm.o
ld.lld -T linker.ld -e main bm.o -o bm.elf

# ⑤ 裸机侧：内存池
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -ffreestanding -Os \
      -ffunction-sections -c pool.c -o pool.o
llvm-size pool.o && llvm-nm -u pool.o && llvm-nm --print-size -S pool.o

# ⑥ 对齐坑（主机侧）
clang -O2 -o sz sz.c && ./sz
```

⚠ **本机环境限制**：Valgrind 未安装且无 root 权限装不了，
[13.3](13.3-Valgrind.md) 全部内容未实测。
