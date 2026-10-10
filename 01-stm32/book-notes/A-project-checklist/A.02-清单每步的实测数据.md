# A.02 清单每步的实测数据

> 书：附录「项目创建清单」（原书 p243）
> 上一篇：[A.01 项目创建清单](A.01-项目创建清单.md) ｜ 下一篇：[A.03 做错会怎样](A.03-做错会怎样.md)
> 对应实验：本次**从零实测**——在 `/tmp/applab` 里真的建了一个能链出 `.bin` 的最小工程
> 工具链：clang 23.1.0 + ld.lld 23.1.0（micromamba `cdev`），目标 `armv7m-none-eabi -mcpu=cortex-m3`

## 书这一节讲什么

**这一篇是 [A.01](A.01-项目创建清单.md) 那 9 步的实测证据。**
每一步都给：命令、产物、真实数字。

⚠ 前提同 A.1：原书 p243 原文手头没有，
所以这里的清单是**本仓库实际走过的步骤**，不是"复述书里的清单"。

## 一、实测产物规模（先有个整体印象）

| 文件 | 行数 | 说明 |
|---|---|---|
| `linker.ld` | **10** | `ENTRY` + `MEMORY` + 4 个 `SECTIONS` |
| `startup.c` | **15** | 向量表 + `Reset_Handler`（搬 `.data` / 清 `.bss`） |
| `main.c` | **12** | 开 GPIOA 时钟 + PA5 翻转 |

**三个文件 37 行就能得到一个能烧的 `.bin`。** 这就是裸机项目的"最小骨架"。

## 二、逐步实测输出

```
### 步骤 4：编译
  ✅ startup.o     1616 B
  ✅ main.o        1280 B

### 步骤 5：链接（ld.lld -T linker.ld --gc-sections -Map=app.map）
   text    data     bss     dec     hex   filename
    210      16       0     226      e2   app.elf

### 步骤 7：生成 .bin
  app.bin = 228 B
```

⚠ **注意 `llvm-size` 的三列不是你以为的三列**。用 `-A` 看分节明细才准：

```
section             size        addr
.vectors              16   0x08000000     ← 向量表，被算进 "data" 列
.text                194   0x08000010
.ARM.exidx            16   0x080000D4     ← 异常回溯表，被算进 "text" 列
.data                  0   0x20000000
.bss                   0   0x20000000
```

所以 Berkeley 格式里的 `text 210 = .text 194 + .ARM.exidx 16`、
`data 16 = .vectors 16`——**.vectors 不带 `SHF_EXECINSTR`，被归到 data**。
第一次看会以为"我的代码有 16 字节数据在 RAM 里"，其实它们在 Flash 最前面。

## 三、⭐ 步骤 8：三项校验（本篇最该抄走的一段）

```
Contents of section .vectors:
 8000000 00500020 15000008 11000008 11000008  .P. ............

  向量表 [0] = 0x20005000   （_estack = 0x20000000 + 20K）
  向量表 [1] = 0x08000015   （Reset_Handler）
  SP 合法（在 RAM 内）      : True
  Reset 合法（Thumb 位为 1）: True
```

| 校验项 | 期望 | 实测 | 为什么 |
|---|---|---|---|
| 向量表 [0] = SP | 落在 RAM 区间内 | `0x20005000` ✅ | 上电第一个装进 SP 的值 |
| 向量表 [1] = Reset | **必须是奇数** | `0x08000015` ✅ | 最低位是 Thumb 标志；偶数 → HardFault |
| 向量表 [1] 落点 | 在 Flash 起始附近 | `0x08000015` ✅ | 越界说明链接脚本写错 |
| ELF 入口 | **≠ 0** | 带 `ENTRY` 时 `0x8000015` ✅ | 见 [A.01](A.01-项目创建清单.md) |

## 四、⭐ 实测：`--gc-sections` 与 `.ARM.exidx` 各值多少字节

同一个工程，四种链接配置：

| 配置 | text+data | 差 |
|---|---|---|
| ① 基线（`--gc-sections`） | **226 B** | —— |
| ② 去掉 `--gc-sections` | **242 B** | +16 B |
| ③ 编译时加 `-fno-unwind-tables` | **226 B** | ⚠ **0 B，没用** |
| ④ 链接脚本 `/DISCARD/` 掉 `.ARM.exidx` | **210 B** | **−16 B** |

两个结论：

1. **`--gc-sections` 在这个小程序上省 16 B**（242 → 226）——
   省的是没被引用的段；工程越大省得越多；
2. ⚠ **`-fno-unwind-tables` 实测无效**：`.ARM.exidx` 那 16 B **还在**。
   要真正去掉它，得在链接脚本里写 `/DISCARD/ : { *(.ARM.exidx) *(.ARM.attributes) }`。

⚠ **但别急着 `/DISCARD/`**：`.ARM.exidx` 是异常回溯表，
去掉它**会让栈回溯失效**（调试 HardFault 时看你不出调用栈）。
这 16 B 换来的是"崩溃时能定位"，**通常值得**。

## 五、完整可复现脚本

```sh
mkdir -p /tmp/applab && cd /tmp/applab
CL=/Users/a0000/micromamba/envs/cdev/bin/clang
LD=/Users/a0000/micromamba/envs/cdev/bin/ld.lld
CF="--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib -ffunction-sections -fdata-sections"

# 2. linker.ld（10 行，含 ENTRY + KEEP）       ← 内容见 A.1 第三节
# 3. startup.c（15 行，向量表 + Reset_Handler） ← 内容见 A.1 第四节
# 5. main.c
$CL $CF -c startup.c -o startup.o       # 1616 B
$CL $CF -c main.c    -o main.o          # 1280 B

# 7. 链接
$LD -T linker.ld --gc-sections -Map=app.map -o app.elf startup.o main.o
llvm-size app.elf          # text 210 / data 16 / bss 0 = 226

# 8. 生成 .bin
llvm-objcopy -O binary app.elf app.bin   # 228 B

# 9. 校验
llvm-objdump -s -j .vectors app.elf      # 头 8 字节 = SP + Reset_Handler
llvm-readelf -h app.elf | grep -i entry  # 必须 ≠ 0
```

## 坑点

| 坑 | 原书怎么说 | 实际是什么（实测） |
|---|---|---|
| "`text/data/bss` 就是代码/数据/未初始化" | —— | ⚠ 实测 **`.vectors` 被算进 `data`**（16 B 在 Flash 最前面），**`.ARM.exidx` 被算进 `text`** |
| "`.bin` 大小 = `text+data`" | —— | ❌ 实测 **226 vs 228**，差 2 B（对齐填充） |
| "`-fno-unwind-tables` 能去掉 `.ARM.exidx`" | —— | ❌ 实测**没用**（仍 16 B）；要用链接脚本 `/DISCARD/` 才去掉（→ 210 B） |
| "`--gc-sections` 就是省空间" | —— | ⚠ 实测省 16 B，但它**同时会删掉没被引用的 ISR**（[A.03](A.03-做错会怎样.md)） |
| "去掉 `.ARM.exidx` 是纯赚" | —— | ⚠ 省 16 B，但**栈回溯失效**——HardFault 时定位变难 |

## 衔接

- **上一篇**：[A.01 项目创建清单](A.01-项目创建清单.md)。
- **下一篇**：[A.03 做错会怎样](A.03-做错会怎样.md)——本篇每步"漏了"的实测后果。
- **链接器展开**：[11 链接器](../11-linker/README.md)。
- **真机版**：[`01-stm32/01-bare-metal`](../../01-bare-metal/README.md)（烧录 Verified OK）。

## 代码自测

<details>
<summary>Q1：为什么 .bin 是 228 B 而 size 报 226 B？</summary>

**对齐填充。** `llvm-size` 报的是各 `SECTIONS` 里内容的字节数总和
（`16 + 194 + 16 = 226`），而 `.bin` 是**从最低地址到最高地址的连续字节**——
中间/末尾的对齐 padding 也算进去了：

```
.vectors   0x08000000 + 16 → 0x08000010
.text      0x08000010 + 194 → 0x080000D2   ← 194 结束在 0xD2
.ARM.exidx 对齐到 4 字节 → 0x080000D4 + 16 → 0x080000E4
                                   0xE4 - 0x00 = 228
```

`0xD2 → 0xD4` 之间那 2 字节就是 padding。

⚠ **算 Flash 占用要按 `.bin` 的大小算，不是按 `size` 的和**——
`size` 会低估。反过来，如果链接脚本里有**地址跳跃**
（比如把某段强制放到 `0x08010000`），`.bin` 会突然变得巨大
（因为它要填满中间的空），**那种情况要看 `.map` 或按段分别抽**。
</details>

<details>
<summary>Q2：.ARM.exidx 到底是什么？裸机上真需要吗？</summary>

**它是 ARM EABI 的异常回溯表**（Exception Index Table），
给栈回溯（unwinding）用的——调试器靠它把"一串地址"还原成"调用栈"。

实测数据：

```
.ARM.exidx    16 B    ← 占 text 列，llvm-size 把它算进 "text"
去掉它：226 B → 210 B（省 16 B）
```

**留着的好处**：HardFault 时 `bt` 能看到调用栈。
裸机上 HardFault 是最常见的崩溃，**能看到调用栈价值很大**。

**去掉的好处**：省 16 B。

| 项目类型 | 建议 |
|---|---|
| 学习 / 调试阶段 | **留着**（16 B 换可定位性，血赚） |
| 量产且 Flash 极紧（如 F030R8 的 64 KB 已经见底） | 可以去掉，但要接受"崩溃只能看寄存器" |
| 用了 `-fno-exceptions` 的 C++ 项目 | 本来就没意义，去掉 |

⚠ **实测踩到的坑**：`-fno-unwind-tables` **去不掉它**（实测仍 16 B）。
要去掉只能靠链接脚本：

```ld
/DISCARD/ : { *(.ARM.exidx) *(.ARM.attributes) }
```

**判据**：先看你的 Flash 预算剩多少。
128 KB 的 F103RB 上 16 B 毫无意义，**留着**；
如果是在 16 KB 的芯片上抠字节，再考虑去掉。
</details>

<details>
<summary>Q3：--gc-sections 到底删了什么？怎么知道它删了不该删的？</summary>

**删的是"从入口点不可达"的段。** 实测这次工程：

```
有 --gc-sections : 226 B
无 --gc-sections : 242 B      → 删掉了 16 B
```

**怎么知道它删了什么**——两个办法：

```sh
# ① 链接时打印被删的段
ld.lld -T linker.ld --gc-sections --print-gc-sections -o app.elf startup.o main.o
#   removing unused section ...

# ② 链完之后查符号表（最实用）
llvm-nm app.elf | grep -E 'Handler|main'      # ISR 还在不在
```

⚠ **必须查的是 ISR**。实测这次工程里：

```
08000010 T Default_Handler
08000014 T Reset_Handler
0800006c T main
→ SysTick_Handler 是否被 gc：已被删除       ← ❌
```

`main.c` 里明明写了 `SysTick_Handler`，但它**没被写进向量表**（向量表只有 4 项），
于是 `--gc-sections` 认为"没人引用它" → 删掉。
这和 [19.03](../19-systick-and-timer/19.03-g_ms与回绕安全的时间比较.md) 的发现是同一个坑。

**检查清单**（每次链完都该过一遍）：

1. 所有 ISR 的名字都在符号表里吗？
2. 向量表（`g_vectors`）还在吗？（漏 `KEEP` → 整个被删，见 [A.03](A.03-做错会怎样.md)）
3. 尺寸比上次小了？**小了不一定是好消息**，先确认不是删错了东西。
</details>
