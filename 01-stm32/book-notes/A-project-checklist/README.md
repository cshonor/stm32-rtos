# 附录「项目创建清单」—— 导航

> 书：附录「项目创建清单」（原书 **p243**）
> 对应实验：本次**从零实测**（`/tmp/applab` 里真的建了一个能链出 `.bin` 的最小工程）
> 工具链：clang 23.1.0 + ld.lld 23.1.0（micromamba `cdev`），`armv7m-none-eabi -mcpu=cortex-m3 -Os`

## 这一篇在讲什么

**原书附录只有一页（p243），没有小节编号。**

⚠ **诚实前提**：原书 p243 的清单原文**我手头没有**（无电子版），
所以**不声称"这就是书里的那张清单"**。
这里写的是**本仓库实际建一个裸机项目时走过的每一步**，每一步都有实测命令与数字。

一句话概括：

> **裸机项目没有"新建工程向导"。少一样东西，链接器多半不报错，
> 而是让你上电后得到一个静默死掉的板子。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| A.1 | 项目创建清单 | [A.1-项目创建清单](A.1-项目创建清单.md) |
| A.2 | 清单每步的实测数据 | [A.2-清单每步的实测数据](A.2-清单每步的实测数据.md) |
| A.3 | 做错会怎样 | [A.3-做错会怎样](A.3-做错会怎样.md) |

> 说明：**原书附录无小节编号**（只有 p243 一页）。
> A.1–A.3 是本仓库按"清单本体 / 实测证据 / 失败对照"拆的，
> 目的是让"照着做"和"做错了怎么查"分成两篇——**清单要能自证，失败要能定位。**

## 核心实测数据（本篇的锚点）

```
① 最小骨架的规模（本次实测）
   linker.ld  10 行   （ENTRY + MEMORY + 4 个 SECTIONS）
   startup.c  15 行   （向量表 + Reset_Handler 搬 .data / 清 .bss）
   main.c     12 行   （开 GPIOA 时钟 + PA5 翻转）
   → 三个文件 37 行 = 一个能烧的 .bin

② 编译 / 链接 / 产物（实测）
   startup.o   1616 B      main.o  1280 B
   llvm-size:  text 210 / data 16 / bss 0 = 226
   app.bin  =  228 B（比 size 的和多 2 B，是对齐填充）

③ ⭐ llvm-size 的三列不是你以为的三列（llvm-size -A 实测）
   .vectors     16 B @ 0x08000000   ← 被算进 "data" 列（不带 SHF_EXECINSTR）
   .text       194 B @ 0x08000010
   .ARM.exidx   16 B @ 0x080000D4   ← 被算进 "text" 列
   .data         0 B @ 0x20000000
   .bss          0 B @ 0x20000000

④ ⭐ 三种链接配置的尺寸对照（实测）
   基线（--gc-sections）            226 B
   去掉 --gc-sections              242 B   （gc 省 16 B）
   -fno-unwind-tables              226 B   ⚠ 无效，.ARM.exidx 还在
   链接脚本 /DISCARD/ .ARM.exidx   210 B   ✅ 省 16 B

⑤ ⭐ 三项校验（本篇最该抄走的一段）
   Contents of section .vectors:
    8000000 00500020 15000008 11000008 11000008
   向量表 [0] = 0x20005000   SP 合法（在 RAM 内）: True
   向量表 [1] = 0x08000015   Reset 合法（Thumb 位为 1）: True
   ELF 入口 = 0x8000015      ≠ 0 ✅

⑥ ⭐⭐ 六条"做错"的实测后果（5 条静默！）
   ① .vectors 漏 KEEP   → 静默；226→206 B，入口变 0x8000001，向量表被删
   ② 漏 ENTRY           → warning；入口 0x0（正常 0x8000015）
   ③ 向量表不写 ISR     → 静默；SysTick_Handler 符号消失（19.3：124→52 B）
   ④ 不搬 .data/不清 .bss → 静默；链接成功（text72/data20/bss8=100），符号位置正常
   ⑤ 漏 -mthumb         → 静默；编译通过，仍是 Thumb（armv7m triple 隐含）
   ⑥ 漏 -mcpu           → 静默；编译通过 exit=0
```

## 读完本篇你应该能回答

- 一个能烧的裸机项目最少要几个文件？（**3 个、37 行**：`linker.ld` / `startup.c` / `main.c`）
- 链接脚本里哪两项漏了会出事？（**`ENTRY`** → 入口 0x0；**`KEEP`** → 向量表被删）
- `llvm-size` 的 `data` 列里为什么有 Flash 里的东西？（**.vectors 不带执行标志**）
- `-fno-unwind-tables` 能去掉 `.ARM.exidx` 吗？（实测 **不能**，要用 `/DISCARD/`）
- 为什么"尺寸变小"反而要警惕？（漏 `KEEP` 时 **226→206 B**，是向量表被删了）
- 漏 `-mthumb` / 漏 `-mcpu` 会报错吗？（实测 **都不会**，`armv7m` triple 隐含 Thumb）
- 六条错误里有几条是静默的？（**5 条**，只有漏 `ENTRY` 给 warning）
- 链完之后最该查什么？（**`g_vectors` 和所有 ISR 都还在吗**——5 秒挡住最贵的两个坑）

## 前置 / 后续

- 前置：[11 链接器](../11-linker/README.md)（`linker.ld` 逐行展开）、
  [03 嵌入式系统编程](../03-embedded-system-programming/README.md)（启动流程）
- 后续：**补充篇 [ch19 SysTick](../19-systick-and-timer/README.md)**（建好项目之后的第一个时基）、
  ch20 FreeRTOS
- **本仓库的自动化版本**：`01-stm32/01-bare-metal` 的
  `make check-lds` / `check-nokeep` / `check-vectors` / `check-stack`
  ——**把本篇的人工校验固化成了 make 目标**
- **LDD- 侧**：内核模块的 `Kbuild` + `make -C $(KDIR) M=$PWD modules` 就是
  "内核替你准备好了清单"，**裸机是你自己当那个构建系统**

## 实验复现

```sh
mkdir -p /tmp/applab && cd /tmp/applab
CL=/Users/a0000/micromamba/envs/cdev/bin/clang
LD=/Users/a0000/micromamba/envs/cdev/bin/ld.lld
CF="--target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib -ffunction-sections -fdata-sections"

# 写 linker.ld（10 行，见 A.1 第三节）/ startup.c（15 行，见 A.1 第四节）/ main.c
$CL $CF -c startup.c -o startup.o && $CL $CF -c main.c -o main.o
$LD -T linker.ld --gc-sections -Map=app.map -o app.elf startup.o main.o
llvm-size app.elf ; llvm-size -A app.elf
llvm-objcopy -O binary app.elf app.bin        # 228 B
llvm-objdump -s -j .vectors app.elf           # 头 8 字节 = SP + Reset_Handler
llvm-readelf -h app.elf | grep -i entry       # 必须 ≠ 0

# 失败①：把 KEEP 去掉再链一次
sed 's/KEEP(\*(\.vectors))/\*(.vectors)/' linker.ld > ld_nokeep.ld
$LD -T ld_nokeep.ld --gc-sections -o f1.elf startup.o main.o
llvm-nm f1.elf | grep g_vectors     # ❌ 没了；尺寸 226 → 206 B

# 失败②：把 ENTRY 那行删掉
$LD -T linker_noentry.ld --gc-sections -o f2.elf startup.o main.o
#   ld.lld: warning: cannot find entry symbol _start; not setting start address
llvm-readelf -h f2.elf | grep -i entry        # 0x0

# 失败③：查 ISR 还在不在
llvm-nm app.elf | grep -E 'Handler|main'      # SysTick_Handler 已被删除
```

⚠ **本机环境限制（诚实标注）**：

1. **没有真机**——所有"上电后怎样"的结论都是**机制推导**，
   实测到的是"链接通过 + 反汇编/符号表正确"这一层。
   （尤其是"不搬 `.data` 会读到 RAM 随机值"这条，**未实测**。）
2. **原书 p243 的清单原文手头没有**，本篇清单是本仓库实际走过的步骤，不是复述。
3. **漏 `-mthumb` / 漏 `-mcpu` 无影响**这一条，
   只在 `--target=armv7m-none-eabi` 下实测成立，换 target 结论可能变。
4. **`-mcpu` 缺失是否影响代码质量**（指令调度、可用指令集）**未实测**，
   实测只确认了"不报错、能编译通过"。
