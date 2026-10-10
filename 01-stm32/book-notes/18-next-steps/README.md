# 第 18 章 后记 —— 章节导航

> 书：第 18 章 后记（原书 p240–242）
> 对应实验：**全部为本次实测**（clang 23.1.0 / macOS arm64 / Apple Silicon）
> + 本仓库现状盘点（`make check-stack`、`llvm-*` 工具链实测）

## 这一章在讲什么

**书的最后一章没有技术内容，是"元建议"：怎么写作、怎么阅读、怎么借鉴、
用哪些工具、学完之后学什么。**

但对本仓库来说，18.4（工具）值得**在本机逐个验证**——
结果是**书里列的 Cppcheck / Doxygen / Valgrind 全都没装**，
而 clang 自带了**零安装的替代品**。

一句话概括全章：

> **技术章节（ch00–ch17）教的是"怎么做"，本章教的是"怎么持续做得对"：
> 写作是检验、阅读是输入、借鉴是复用、工具是把纪律自动化。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 18.1 | 学会写作 | [18.1-学会写作](18.1-学会写作.md) |
| 18.2 | 学会阅读 | [18.2-学会阅读](18.2-学会阅读.md) |
| 18.3 | 学会合作与创造性借鉴 | [18.3-学会合作与创造性借鉴](18.3-学会合作与创造性借鉴.md) |
| 18.4 | 有用的开源工具 | [18.4-有用的开源工具](18.4-有用的开源工具.md) |
| 18.5 | 永不停上学习 | [18.5-永不停上学习](18.5-永不停上学习.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p240–242），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（18.1–18.5），与顶层索引一致。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 18.1 讲写作 | 落到本仓库纪律：**"原书怎么说 / 实际是什么"表 + 每个数字有出处 + 未实测要标注**；⭐ **实测证据**：本次 ch11–17 拆分中，顶层索引里 **7 章的小节范围有 6 章是错的**（11/12/13/14/15/17 全部订正）；另有 **3 处"以为测过其实没测"**被暴露（Valgrind 整篇、次正规 FPU 陷阱、GNU ld 顺序） |
| 18.2 讲阅读 | ⭐ 实测给 libopencm3 "量体重"：**3.0 MB / 53 成员 / 677 符号**；⭐ **读反汇编的威力实测**：`gpio_set` 只有 **2 条指令**（`str r1,[r0,#0x10]` = 写 BSRR），一眼看穿"为什么要原子置位"；给出四把工具（`ar -t` / `nm` / `objdump -d` / `size`） |
| 18.3 讲借鉴 | ⭐ 用 `gpio_set` 那 2 条指令做完整的"拆 → 用"示范（本仓库改用 `static inline`，因为约束不同）；列出本仓库**已借鉴的十处**（都有实测数据）；⚠ 四步检查法 + 五条"实测推翻课本"的对照 |
| 18.4 讲工具 | ⭐ **全部实测**：Cppcheck/Doxygen/Valgrind **❌ 未安装**；sqlite3 ✅ 3.54.0、clang-tidy ✅ 23.1.0、lldb ✅ 22.1.8、make ✅ 4.4.1、cmake ✅ 4.4.3；⭐ **两类样本的对照实测**：样本 B（越界+双重释放）**编译期全开关 0 条、`--analyze` 0 条、clang-tidy 0 条，只有 ASan 抓到**；⚠ `scan-build` 本机跑不通（stdio.h 找不到 → 假阴性 "0 bugs"）；⚠ `clang-tidy` 默认 0 条，必须显式 `-checks` |
| 18.5 讲后续 | 诚实评估"书带你走到哪"；三个判据问题（启动 / 中断 / .data 双地址）；**MCU ↔ LDD- 对照表**；下一站路线图（SysTick → UART+DMA → FreeRTOS → 时钟树 → Zephyr）；本仓库现状盘点（44 篇、链接 1692 条失效 0） |

## 核心实测数据（本章的锚点）

```
① ⭐ 写作能抓出错误（本次 ch11–17 拆分的真实数据）
顶层索引 7 章的小节范围，6 章是错的：
  11: 11.1–11.9 → 11.1–11.6      14: 14.1–14.8 → 14.1–14.6
  12: 12.1–12.8 → 12.1–12.6      15: 15.1–15.5 → 15.1–15.4
  13: 13.1–13.6 → 13.1–13.4      17: 17.1–17.7 → 17.1–17.6
  16: 16.1–16.7 ✅ 本来就是对的
另有 3 处"以为测过其实没测"被暴露：Valgrind 整篇 / 次正规 FPU 陷阱 / GNU ld 顺序

② ⭐ 给 libopencm3 量体重
$ llvm-ar -t libopencm3_stm32f1.a | wc -l                       → 53 个成员
$ llvm-nm libopencm3_stm32f1.a | grep -cE '^[0-9a-f]+ [TtDdBbWwRr] ' → 677 个符号
$ ls -lh libopencm3_stm32f1.a                                    → 3.0 MB
⚠ 3.0 MB ≠ 固件会变大 3 MB（17.3 实测：按需抽取只进用得上的成员）

③ ⭐ 读反汇编的威力：libopencm3 的 gpio_set
$ llvm-objdump -d --no-show-raw-insn --disassemble-symbols=gpio_set libopencm3_stm32f1.a
00000000 <gpio_set>:
       0:  str r1, [r0, #0x10]     ← BSRR（偏移 0x10）：写 1 置位，写 0 无效
       2:  bx  lr
→ 2 条指令 / 4 字节；一眼看穿"为什么置位要原子（不读-改-写）"

④ ⭐ 工具可用性盘点（本机实测）
cppcheck ❌ 未安装     doxygen ❌ 未安装     valgrind ❌ 未安装     gdb ❌ 未安装
openocd ❌ 未安装      include-what-you-use ❌ 未安装
sqlite3 ✅ 3.54.0      clang-tidy ✅ LLVM 23.1.0   lldb ✅ 22.1.8
make ✅ GNU Make 4.4.1  cmake ✅ 4.4.3
clang 自带（零安装）：clang --analyze / scan-build / clang-format / run-clang-tidy

⑤ ⭐⭐ 三类工具在同一批 bug 上的表现（本章最重要的数据）
样本 A（buggy.c：未初始化 + 符号转换 + NULL 解引用）
  编译期 -Wall -Wextra -Wconversion -Wshadow : 2 条（未初始化 + sign-conversion）
  clang --analyze                            : ✅ 1 条 NULL 解引用（带完整路径）
  clang-tidy -checks='-*,clang-analyzer-*,bugprone-*' : ✅ 2 条
  ASan + UBSan（运行期）                      : ✅ SEGV + 调用栈（buggy.c:13 ← main:28）

样本 B（buggy2.c：栈溢出 + 堆溢出 + 双重释放，3 个 bug）
  编译期全开关      : 0 条   ← ⚠
  clang --analyze   : 0 条   ← ⚠
  clang-tidy        : 0 条   ← ⚠
  ASan + UBSan      : ✅ ERROR: AddressSanitizer: stack-buffer-overflow buggy2.c:8

→ 结论：越界/双重释放这类 bug，编译期工具抓不到，必须跑 sanitizer

⑥ ⚠ scan-build 在本机跑不通（假阴性）
$ scan-build clang -c buggy.c
buggy.c:1:10: fatal error: 'stdio.h' file not found
scan-build: 0 bugs found.        ← ⚠ 假的，编译根本没成功
原因：xcrun --show-sdk-path 返回空（没装 Xcode CLT）
✅ 改用 clang --analyze（实测有效）

⑦ ⚠ clang-tidy 默认 0 条，必须显式开 checks
$ clang-tidy buggy.c -- -Wall                                   → 0 条
$ clang-tidy buggy.c -checks='-*,clang-analyzer-*,bugprone-*'    → 2 条
   buggy.c:13:18 null pointer dereference [clang-analyzer-core.NullDereference]
   buggy.c:17:17 narrowing conversion 'uint32_t'→'int' [bugprone-narrowing-conversions]

⑧ 每天都在用的四个（零成本，本仓库已在用）
clang -Wall -Wextra -Wconversion -Wshadow -Werror          # ① 警告开满
clang --analyze -Xclang -analyzer-output=text foo.c         # ② 静态分析（零安装）
clang -O1 -g -fsanitize=address,undefined -o t t.c && ./t   # ③ 运行期
clang -fstack-usage -c foo.c && cat foo.su ; llvm-size -A   # ④ 资源账本

⑨ -fstack-usage 实测输出
$ make check-stack（本仓库 01-bare-metal）
main.c:32:stack_probe   128   static
main.c:47:main            0   static
--- 对照 SRAM 容量 ---
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 20K
本次另一例（buggy.c）：process 48 static / main 0 static；__text 140 / __data 8

⑩ 本仓库已有的 make 目标（实测可用）
00-toolchain-clang: all size dump sections symbols check-lds check-libc check-eabi clean
01-bare-metal:      all size dump sections symbols vectors compare
                    check-nokeep check-isr check-gpr check-stack check-lds clean
02-libopencm3:      all lib size vectors dump flash openocd gdb
⚠ flash/openocd/gdb 需要真机 + openocd（本机未安装）

⑪ 本仓库现状盘点
book-notes 已拆分：11(6) 12(6) 13(4) 14(6) 15(4) 16(7) 17(6) 18(5) = 44 篇
链接校验：1692 条，失效 0
01-stm32/ 实验代码：9 个 .c/.h，1120 行
libopencm3：已编译 libopencm3_stm32f1.a（3.0 MB / 53 成员 / 677 符号）
```

## 读完本章你应该能回答

- 写作到底有什么用？（实测：**7 章索引数字错了 6 章**，不写下来就发现不了）
- 没实测过的内容怎么处理？（**写出来并标注"未实测"**）
- 代码注释该写什么？（**写"为什么"，不写"做了什么"**）
- 读源码从哪开始？（先量体重 → 定位 → 深入；**别从 RTOS 开始**）
- `gpio_set` 的反汇编说明了什么？（**2 条指令**，写 BSRR，置位原子、不读-改-写）
- 读编译产物能发现什么"打脸"的事？（`static inline` 在 `-O0` 下 N 份、代码宏不省代码、`-Os` 常量折叠吃掉 `__aeabi_fmul`）
- 借鉴和抄袭的区别？（**有没有拆出"它解决什么问题"**）
- 书里列的 Cppcheck / Doxygen / Valgrind 在本机能用吗？（**全都没装**）
- 编译期警告全开能抓到越界吗？（⚠ **不能**，实测 0 条）
- 那越界/双重释放靠什么抓？（**ASan/UBSan**，实测抓到 stack-buffer-overflow）
- `scan-build` 报 0 bugs 是真的没问题吗？（⚠ **可能是假阴性**，本机 stdio.h 找不到）
- `clang-tidy` 为什么跑出 0 条？（⚠ **默认 checks 不开**，要显式 `-checks`）
- 工具按什么顺序上？（警告开满 → `clang --analyze` → sanitizer → 栈/尺寸账本）
- ASan 有什么抓不到的？（⚠ 双重释放只在 `-O0`；macOS LSan 不报泄漏）
- 每天该看的两个数字是什么？（**栈用量 + 代码尺寸**）
- 书学完了吗？（只到"能在板子上跑 C"；RTOS/时钟树/低功耗/EMC 都没进门）
- 判断"学透了"的三个问题是什么？（启动流程 / 中断机制 / `.data` 双地址）
- 接下来先学什么？（**SysTick → UART+DMA → FreeRTOS → 时钟树 → Zephyr**）

## 前置 / 后续

- 前置：**全书 ch00–ch17**（本章是对它们的元总结）
- 后续：**补充篇 [ch19 SysTick/通用定时器](../19-systick-and-timer/README.md)**（书里没写但必须会，✅ 2026-09-28 已拆 19.1–19.7）
- **LDD- / TLPI 侧**：本章的"工具箱"在内核侧对应
  `sparse`（内核静态分析）、`coccinelle`（语义补丁）、
  `KASAN` / `UBSAN`（内核版 sanitizer）、`kmemleak`、`ftrace` / `perf`——
  **和用户侧的工具是同一套思路，只是无法在内核里随便跑**
  （所以内核才有 `CONFIG_KASAN` 这样的编译选项）。
- **HFT 侧**：低延迟场景下的工具纪律与裸机同构——
  **任何"听起来更快"的优化都要实测**（对照 [18.3](18.3-学会合作与创造性借鉴.md) 的四步检查），
  并且**资源账本要持续可见**（延迟直方图而不是平均延迟）。

## 实验复现

```sh
# ① 工具可用性盘点
for t in cppcheck doxygen valgrind sqlite3 clang-tidy gdb lldb openocd make cmake; do
  command -v $t >/dev/null && echo "$t ✅" || echo "$t ❌"; done

# ② 编译期警告（对照样本 A / B）
clang -Wall -Wextra -Wconversion -Wshadow -c buggy.c  -o /dev/null   # 2 条
clang -Wall -Wextra -Wconversion -Wshadow -c buggy2.c -o /dev/null   # 0 条 ⚠

# ③ 静态分析（clang 自带，零安装）
clang --analyze -Xclang -analyzer-output=text buggy.c       # ✅ 1 条 NULL 解引用
clang --analyze buggy2.c                                    # 0 条 ⚠

# ④ clang-tidy（⚠ 必须显式开 checks）
clang-tidy buggy.c -- -Wall                                       # 0 条 ⚠
clang-tidy buggy.c -checks='-*,clang-analyzer-*,bugprone-*'       # 2 条 ✅

# ⑤ scan-build（⚠ 本机跑不通）
scan-build clang -c buggy.c        # fatal error: 'stdio.h' file not found → 假 0 bugs

# ⑥ 运行期 sanitizer（⭐ 越界/双重释放的唯一手段）
clang -O1 -g -fsanitize=address,undefined -o b2 buggy2.c && ./b2
#   ERROR: AddressSanitizer: stack-buffer-overflow ... in process buggy2.c:8

# ⑦ 资源账本
clang -fstack-usage -c buggy.c && cat buggy.su     # process 48 / main 0
cd 01-stm32/01-bare-metal && make check-stack          # stack_probe 128 / main 0，对照 20K SRAM
llvm-size -A buggy_exe                              # __text 140 / __data 8

# ⑧ 读 libopencm3（18.2 的素材）
llvm-ar -t third_party/libopencm3/lib/libopencm3_stm32f1.a | wc -l        # 53
llvm-nm  third_party/libopencm3/lib/libopencm3_stm32f1.a | grep -cE '^[0-9a-f]+ [TtDdBbWwRr] '  # 677
llvm-objdump -d --no-show-raw-insn --disassemble-symbols=gpio_set \
             third_party/libopencm3/lib/libopencm3_stm32f1.a              # 2 条指令
```

⚠ **本机环境限制（诚实标注）**：

1. **Cppcheck / Doxygen / Valgrind / gdb / openocd 均未安装**——
   书里前三个是"必备"推荐，本机改用 clang 自带工具 + ASan/UBSan。
2. **`scan-build` 跑不通**（`xcrun --show-sdk-path` 为空 → 找不到 `stdio.h`），
   输出 "0 bugs found" 是**假阴性**，要改用 `clang --analyze`。
3. **没有真机**：`make flash` / `openocd` / `gdb` 相关目标无法实测。
4. **SQLite 在 MCU 上的占用**（约 500 KB Flash）**未实测**，
   只确认了主机侧 `sqlite3` 3.54.0 可用。
