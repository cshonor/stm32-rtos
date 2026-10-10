# labs/01-hello —— 工具台的参考实验

> 板子：**Blue Pill（STM32F103C8T6）**，板载 LED 接 PC13，低电平点亮
> 定位：工具台的"最小可跑工程"。它的价值不在代码，而在 **Makefile 只有 4 行** ——
> 规则的重复被 `mk/arm-clang.mk` 吃掉了，这里是那个改造的结果长什么样。

## 文件

| 文件 | 作用 |
|---|---|
| `startup.c` | 向量表 + `Reset_Handler`（搬 .data / 清 .bss / 调 main）+ `__aeabi_*` 兜底 |
| `main.c` | 开 GPIOC 时钟 → 配 PC13 推挽输出 → BSRR 翻转 |
| `linker.ld` | Flash 64K @0x08000000 / SRAM 20K @0x20000000（与 `boards/f103c8t6.mk` 一致） |
| `Makefile` | **4 行**：BOARD / TARGET / SRCS / include |

## 跑起来

```bash
source tools/env.sh --export         # 工具不在 PATH 上时先做这一步
make                                 # 编译，看体积账单
make flash                           # 烧进板子（需要外接 ST-Link + SWD 排针）
make probe                           # 只读回读：向量表 + pc/msp
../../tools/dbg.sh hello.elf         # 源码级调试（自动起 openocd，退出时收摊）
```

## 实测输出

（按仓库纪律：真机跑通后把 `make` / `make flash` / `make probe` 的输出贴在这里。
  工具台本身已在 Windows 上用 `bash tools/env.sh` 验证编译链完整可用。）

```
（待补：真机烧录 + 回读）
```

## 为什么留着它

它是 README 里那句"各 lab 的 Makefile 只有四行"的实物证据。
想验证工具台改对了没有，看一眼这个目录的 Makefile 就够了。
