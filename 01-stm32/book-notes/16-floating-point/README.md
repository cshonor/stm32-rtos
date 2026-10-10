# 第 16 章 浮点数 —— 章节导航

> 书：第 16 章 浮点数（原书 p219–226）
> 对应实验：**全部为本次实测**（clang 23.1.0 / macOS arm64）
> + **交叉编译真链接**（`--target=armv7m-none-eabi -mcpu=cortex-m3` + `ld.lld` + 本仓库 `linker.ld`）

## 这一章在讲什么

**书把浮点放在第二部分"用于大型机器的 C 语言编程"里，原因本身就是一条结论：
书里的板子 NUCLEO-F030R8 是 Cortex-M0——没有 FPU，浮点全靠软件模拟。**

对裸机轨来说，这一章的价值不在"学会用 float"，
而在**知道什么时候不该用**：

1. **浮点有三组特殊值**（`inf` / `NaN` / 次正规），**整数一组都没有**；
2. **精度不是固定的**——ULP 随量级指数增长（实测 1 处 1.19e-07、1e9 处 **64**）；
3. **没有 FPU 时，浮点是库函数调用**（实测 `U __aeabi_fmul`），
   而**整数和定点不是**。

一句话概括全章：

> **本章是"选型"章：先证明浮点有多麻烦，再给出替代方案
> （整数 + 单位命名 / Q16.16 定点）。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 16.1 | 数字表示 | [16.1-数字表示](16.1-数字表示.md) |
| 16.2 | 舍入误差 | [16.2-舍入误差](16.2-舍入误差.md) |
| 16.3 | 精度位数 | [16.3-精度位数](16.3-精度位数.md) |
| 16.4 | 无穷大 | [16.4-无穷大](16.4-无穷大.md) |
| 16.5 | 不是数字（NaN） | [16.5-不是数字(NaN)](16.5-不是数字NaN.md) |
| 16.6 | 次正规数 | [16.6-次正规数](16.6-次正规数.md) |
| 16.7 | 替代方案 | [16.7-替代方案](16.7-替代方案.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p219–226），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（16.1–16.7），与顶层索引一致。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 16.1 讲数字表示 | 补上**位模式实测**（`0.1f = 0x3dcccccd` → 指数 123−127=−4 → 值 `0.10000000149011612`）；⚠ **`long double` 在 macOS arm64 上就是 `double`**（实测 8 字节 / `LDBL_DIG=15`）；⚠ **M3 vs M4F 的未定义符号对照实测**：M4F 上 `float` 变硬件（`vmul.f32`）、**`double` 仍走 `__aeabi_d*`** |
| 16.2 讲舍入误差 | 三类误差全测：`0.1+0.2` 差值 **5.55e-17**、累加 10 次（`float` 偏大 `1.0000001`、`double` 偏小 `0.99999999`、**Kahan 修正回 1**）、⚠ **累加顺序差 1000**（`1e16+1000×1` vs `1000×1+1e16`） |
| 16.3 讲精度位数 | **ULP 表实测**（1 → 1.19e-07；**1e7 → 1**；1e9 → **64**）；⚠ **`2^24` 是 float 精确整数上限**（实测 `2^24+1 == 2^24` 为"是"、`2^23+1` 为"否"）；⚠ `%.15f` 打 `0.1f` 得 `0.100000001490116`，后 6 位是噪声 |
| 16.4 讲无穷大 | `inf` 位模式 **0x7ff0000000000000**；⚠ **`FLT_MAX * 2 = inf`**（没有除法也会产生 inf）；⚠ `inf - inf` / `inf * 0` → **NaN**；⚠ **clamp 挡不住 NaN** |
| 16.5 讲 NaN | ⚠ **六个比较运算符实测全为假**（只有 `!=` 为真）；⚠ `!(x < 1.0)` 与 `x >= 1.0` **在 NaN 上不等价**；freestanding 无 `<math.h>` → 只能 `x != x`；⚠ `-ffast-math` 会把判断优化掉 |
| 16.6 讲次正规数 | ⚠ **`1e-320` 只剩 10 个有效位**（正常 53 位）；⚠ **1.0 除 2：1074 次到最小次正规、1075 次静默归零**；`DBL_TRUE_MIN/2 = 0`；"次正规走 FPU 陷阱"**本机未实测，已标注** |
| 16.7 讲替代方案 | ⭐ **核心实测：M3 上真链接同一段 `a*b+c`**——整数 ✅ 68 B、Q16.16 ✅ 76 B（只多 8 B）、**`float` ❌ 链接失败（`__aeabi_fmul`）**、**`double` ❌ 失败（`__aeabi_dmul`）**；⚠ Q16.16 也会溢出（实测 `300×300 → 24464`，回绕比 inf 更难发现）；⚠ 累加 500 万次：float `4897.39` vs Q16 `4959.11`——**定点不是更准，是更可预测**；⚠ `snprintf("%.2f")` 比整数拆分慢 **1.9 倍**（186 vs 100 ns） |
| 书里没提 | 本仓库取向：**物理量一律整数 + 单位后缀**（`temp_mC`/`volt_mV`），不用 `double`，`%f` 换成整数拆分 |

## 核心实测数据（本章的锚点）

```
① 类型与精度常量（主机 clang 23.1.0 / macOS arm64）
sizeof float=4 double=8 long double=8        ← ⚠ long double == double（AAPCS64）
FLT_DIG=6 DBL_DIG=15 LDBL_DIG=15
FLT_EPSILON=1.192092896e-07  DBL_EPSILON=2.2204460492503131e-16
FLT_MIN=1.175494351e-38   FLT_MAX=3.402823466e+38
DBL_MIN=2.2250738585072014e-308  DBL_MAX=1.7976931348623157e+308
FLT_TRUE_MIN=1.401298464e-45  DBL_TRUE_MIN=4.940656458e-324
FLT_MANT_DIG=24 DBL_MANT_DIG=53

② 位模式
0.1f  = 0.10000000149011612  0x3dcccccd   （指数 0x7B=123 → 123-127 = -4）
1.0f  = 1                    0x3f800000
-0.0f = -0                   0x80000000    ← ⚠ 与 0.0 相等但位模式不同
0.1   = 0.10000000000000000555  0x3fb999999999999a
0.2   = 0.20000000000000001110  0x3fc999999999999a
0.3   = 0.29999999999999998890  0x3fd3333333333333
inf   = 0x7ff0000000000000（指数全 1，尾数全 0）
NaN   = 0x7ff8000000000000（指数全 1，尾数非 0）
1e-320 = 9.999888672e-321     0x00000000000007e8（指数全 0 = 次正规）

③ 舍入误差
0.1 + 0.2 = 0.30000000000000004441   差值 5.5511151231257827021e-17
float  0.1f 累加 10 次 = 1.0000001192092895508   （偏大）
double 0.1  累加 10 次 = 0.99999999999999988898   （偏小）
Kahan  0.1  累加 10 次 = 1                        （✅ 修正）
大数先加: 1e16 + 1000×1 = 10000000000000000   ← ⚠ 1000 全丢
小数先加: 1000×1 + 1e16 = 10000000000001000   ← ✅ 保住
1e15 + 1 == 1e15 ? 否   |   1e16 + 1 == 1e16 ? 是

④ 精度位数 / ULP（float）
1          → 1.19209e-07
1e6        → 0.0625
1e7        → 1        ← ⚠ 加 1 已无意义
1e9        → 64
1e15       → 8.38861e+06
打印位数：%.6f → 0.100000 | %.9f → 0.100000001 | %.15f → 0.100000001490116（噪声）
2^24 + 1 == 2^24 ? 是   ← ⚠ float 精确整数上限 2^24 = 16777216
2^23 + 1 == 2^23 ? 否

⑤ 无穷大 / NaN
1.0/0.0   = inf         -1.0/0.0 = -inf
inf + 1   = inf         inf - inf = nan      inf * 0 = nan
FLT_MAX*2 = inf         ← ⚠ 没有除法也会产生 inf
NaN: < 0  > 0  <= 0  >= 0  == 0 全为假，只有 != 为真

⑥ 次正规
DBL_MIN = 2.2250738585072014e-308   DBL_TRUE_MIN = 4.940656458e-324
1e-320 是次正规（位模式 0x7e8，只剩 10 个有效位）
1.0 连续除 2：1074 次 = 4.940656458e-324 | 1075 次 = 0   ← ⚠ 静默归零
DBL_TRUE_MIN / 2 = 0

⑦ ⭐ 裸机真链接（M3, -Os, volatile 输入, linker.ld）
整数版   .o 未定义符号 无                 → ✅ Flash 68 B（text 56 + data 12）
Q16.16版 .o 未定义符号 无                 → ✅ Flash 76 B（text 64 + data 12）
float版  .o 未定义符号 __aeabi_fmul/fadd  → ❌ ld.lld: undefined symbol: __aeabi_fmul
double版 .o 未定义符号 __aeabi_dmul/dadd  → ❌ ld.lld: undefined symbol: __aeabi_dmul
⚠ 失败原因：本机没有 armv7m 的 compiler-rt builtins（lib/clang/23/lib 下只有 *osx*）

⑧ 交叉编译的未定义符号对照
M3 （-mcpu=cortex-m3）              : __aeabi_fadd fmul fdiv + __aeabi_dadd dmul ddiv
M4F（-mcpu=cortex-m4 -mfloat-abi=hard）: 只剩 __aeabi_dadd dmul ddiv   ← ✅ float 变硬件
M4F 反汇编：fmul_add → vmul.f32/vadd.f32 | fdiv → vdiv.f32 | ddiv → bl __aeabi_ddiv

⑨ Q16.16 定点（主机实测）
范围 ±32768.0   分辨率 1/65536 = 1.5258789e-05
1.5×2.25+0.5 = 3.8750000000（与 float 一致，位模式 0x0003e000）
⚠ 300.0×300.0 = 24464.0（正确 90000，回绕）
累加 500 万次（+0.001）：float 4897.391602（−2.05%）| Q16 4959.106445（−0.82%，可算）

⑩ 格式化代价（主机 -O2）
snprintf("%.2f")     : 186 ns/次 → "23.45"
snprintf 整数拆分     : 100 ns/次 → "23.450"
主机算术吞吐（-O2, 1e8 次）：int 0.238 | float 1.176 | double 0.938 ns/次
                             除法：int 0.626 | float 0.940 | double 0.939 ns/次
```

## 读完本章你应该能回答

- `long double` 一定比 `double` 精度高吗？（⚠ **本机实测是一样的**，8 字节）
- `0.1f` 的实际值是多少？（**0.10000000149011612**）
- `-0.0` 存在吗？`== 0.0` 成立吗？（存在，`0x80000000`；**成立**）
- 为什么 M4F 上 `float` 快而 `double` 不快？（**只有单精度 FPU**；实测未定义符号对照）
- `0.1 + 0.2` 和 `0.3` 差多少？（**5.55e-17**）
- 累加 10 次 `0.1`，`float` 和 `double` 谁更接近 1？（`float` 偏大、`double` 偏小；**Kahan 正好得 1**）
- 加法顺序会改变结果吗？差多少？（会，实测差 **1000**）
- `float` 在 `1e7` 附近的间隔是多少？（**1**）
- `float` 能精确表示的整数上限是多少？（**2^24 = 16777216**）
- `FLT_MIN` 和 `FLT_TRUE_MIN` 差几个数量级？（**7 个**）
- 浮点除零会崩溃吗？（**不会**，得到 `inf`）
- 没有除法也可能产生 `inf` 吗？（**会**，实测 `FLT_MAX * 2`）
- `inf - inf` 是什么？（**NaN**）
- NaN 参与的比较有几个为真？（**只有 `!=`**；`<` `>` `<=` `>=` `==` 全假）
- `!(x < 1.0)` 等价于 `x >= 1.0` 吗？（⚠ **NaN 时不等价**）
- clamp 能挡住 NaN 吗？（**不能**，NaN 会穿过）
- 裸机上没有 `<math.h>`，怎么检测 NaN？（`x != x`；⚠ 别开 `-ffast-math`）
- 1.0 连续除 2，第几次归零？（**1075 次**；1074 次是最小次正规）
- 下溢成 0 会报错吗？（**不会**，静默）
- M3 上同一段 `a*b+c`，整数/定点/float/double 哪个链接得过？（**整数 68 B、Q16 76 B 通过；float/double 失败**）
- Q16.16 乘法为什么要 `int64_t` 中转？（中间是 Q32.32）
- Q16.16 的溢出表现是什么？（**回绕**：实测 `300×300 → 24464`）
- 定点比浮点更准吗？（⚠ **不是更准，是更可预测**——实测 4897 vs 4959）
- `snprintf("%.2f")` 比整数拆分慢多少？（**1.9 倍**，186 vs 100 ns）
- M4F 上用浮点前要先做什么？（设 **`SCB->CPACR`**，否则 UsageFault）

## 前置 / 后续

- 前置：[第 4 章 位操作](../04-numbers-and-bitops/README.md)（位模式、字节序）、
  [第 7 章 栈帧](../07-stack-frame-functions/README.md)（栈预算；FPU 中断帧 +136 B）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（union 取位模式、`packed`）、
  [第 9 章 串口](../09-uart-serial/README.md)（`mini_printf` 340 B，不含 `%f`）、
  [第 10 章 中断](../10-interrupts/README.md)（ISR 里别用浮点）、
  [第 11 章 链接器](../11-linker/README.md)（Flash 预算、软浮点库）、
  [第 15 章 原始 I/O](../15-cli-args-raw-io/README.md)（二进制位模式传输）
- 后续：[第 17 章 模块化编程](../17-modular-programming/README.md)
- **LDD- / 内核侧**：
  - **内核里默认禁用浮点**，要用必须 `kernel_fpu_begin/end`——
    和裸机的"谨慎使用"是同一个理由：保存/恢复 FPU 寄存器代价高；
  - 内核的 `printk` **不支持 `%f`**（浮点格式化被刻意排除），
    和 [16.7](16.7-替代方案.md) 实测"`%f` 比整数拆分慢 1.9 倍"同源；
  - `-mgeneral-regs-only` / `CONFIG_KERNEL_FPU` 之类的开关，
    本质就是本章"有没有 FPU、要不要库"的问题在内核里的版本；
  - HFT 侧：行情价格一律用**定点整数**（`price_ticks`），
    理由和嵌入式完全一致——**确定性优先于精度**。

## 实验复现

```sh
# ① 主机：常量 / 位模式 / 舍入 / inf / NaN / 次正规
clang -O0 -Wall -o fp fp.c && ./fp

# ② 精度位数：ULP 表、2^24 边界、打印位数
clang -O1 -Wall -o prec prec.c && ./prec

# ③ 算术吞吐（主机有 FPU 的对照）
clang -O2 -Wall -o bench2 bench2.c && ./bench2

# ④ %f vs 整数拆分
clang -O2 -Wall -o pf pf.c && ./pf

# ⑤ Q16.16 定点
clang -O1 -Wall -o q q.c && ./q

# ⑥ 交叉编译：M3 / M4F 的未定义符号对照
clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -c m3.c -o m3.o
llvm-nm -u m3.o
clang --target=armv7em-none-eabi -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 \
      -Os -ffreestanding -c m3.c -o m4.o
llvm-nm -u m4.o && llvm-objdump -d m4.o   # float → vmul.f32，double → bl __aeabi_dmul

# ⑦ ⭐ 裸机真链接：整数 / Q16.16 / float / double
for v in i q f d; do
  clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib \
        -ffunction-sections -fdata-sections -c vec.c    -o vec_$v.o
  clang --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -Os -ffreestanding -nostdlib \
        -ffunction-sections -fdata-sections -c app_$v.c -o app_$v.o
  ld.lld -T ../../01-stm32/00-toolchain-clang/linker.ld --gc-sections -o app_$v.elf vec_$v.o app_$v.o
  llvm-size app_$v.elf
done
```

⚠ **本机环境限制（诚实标注）**：

1. **没有 armv7m 的 compiler-rt builtins**：
   `lib/clang/23/lib/` 下只有 `*osx*` 版本，
   所以 `float`/`double` 版**链接失败**（`undefined symbol: __aeabi_fmul`）。
   这是**环境限制，不是"浮点不能用"**——但它证明了"浮点需要额外运行时库"。
2. **没有板子**，M3 上浮点的实际周期数**未实测**；
   [16.7](16.7-替代方案.md) 只给出了"是库函数调用"的证据（`U __aeabi_f*`）。
3. **次正规在 FPU 上变慢**（走微码陷阱）**未实测**，
   [16.6](16.6-次正规数.md) 中标注为"机制说明"。
4. **FPU 使能导致的中断帧变大（136 B）** 引自既有笔记，**非本次实测**。
