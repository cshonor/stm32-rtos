# Makefile —— 01-stm32/03-gpio-blink
#
# 目标：把 NUCLEO-F103RB 的 LD2（PA5）点起来，并用调试器"读回"证明它真的在闪。
#
# 构建规则、烧录、调试全部来自 mk/arm-clang.mk（与 01-stm32/00、01、labs/ 同一套）。
# 本文件只保留这个实验**特有**的东西：探针程序 portprobe、寄存器反汇编、栈用量。
#
#   make          构建（blink_gpio.elf / .bin + 段大小）
#   make flash    烧进板子并复位运行（openocd + ST-Link）
#   make probe    ★ 只读探测：halt 后读回向量表 / RCC / GPIOA / 观测点变量
#   make gdb      源码级断点 + 单步（书 3.6 / 3.7）；或 tools/dbg.sh blink_gpio.elf
#   make regs     main 的反汇编，看每条 C 语句几条指令
#
# 前置（工具不在 PATH 上时）：
#     source tools/env.sh --export

BOARD  ?= f103rb
TARGET := blink_gpio
SRCS   := startup.S main.c

include ../../mk/arm-clang.mk

# ---------------------------------------------------------------------------
# 本目录特有的观测点：追加到 `make probe` 的 openocd 命令里
# （mk/arm-clang.mk 的 probe 默认只读向量表 + pc/msp）
# ---------------------------------------------------------------------------
PROBE_EXTRA := \
  -c "echo {=== RCC_APB2ENR @0x40021018（应=0x4）===}" -c "mdw 0x40021018 1" \
  -c "echo {=== GPIOA_CRL / CRH / IDR / ODR / BSRR / BRR ===}" -c "mdw 0x40010800 6" \
  -c "echo {=== 观测点变量 @0x20000000 ===}" -c "mdw 0x20000000 24"

# ---------------------------------------------------------------------------
# 探针程序：单独一个可执行文件，用来"量"时钟未开时的寄存器行为。
# 它和主程序不是一回事：主程序点灯，探针只读、只回答"会发生什么"。
# ---------------------------------------------------------------------------
PROBE := portprobe

portprobe.o: portprobe.c
	$(CC) $(CFLAGS) -c $< -o $@

$(PROBE).elf: startup.o portprobe.o linker.ld
	$(LD) $(LDFLAGS) -Map=$(PROBE).map -o $@ startup.o portprobe.o

$(PROBE).bin: $(PROBE).elf
	$(OBJCOPY) -O binary $< $@

# 烧探针程序（会覆盖主程序，跑完停在死循环），测完记得 make flash 把主程序烧回去
probe-ports: $(PROBE).bin
	$(OPENOCD_CMD) -f $(BOARD_OPENOCD_CFG) \
	  -c "program $(PROBE).bin $(BOARD_FLASH_ORIGIN) verify reset exit"

# 读探针结果（先 make probe-ports，再 make read-ports）
read-ports:
	@echo "=== 变量地址 ==="
	@$(NM) -n --print-size $(PROBE).elf | grep -E "stage|c_|b_|d_"
	@echo "=== 读回 ==="
	$(OPENOCD_CMD) -f $(BOARD_OPENOCD_CFG) \
	  -c "init" -c "halt" -c "wait_halt 1000" \
	  -c "mdw $(BOARD_RAM_ORIGIN) 28" -c "reg pc" \
	  -c "shutdown"

# ---------------------------------------------------------------------------
# 观察
# ---------------------------------------------------------------------------
# 书 3.4「探索构建过程」：看每条 C 语句被编成几条指令
regs: $(TARGET).elf
	$(OBJDUMP) -d --no-show-raw-insn $(TARGET).elf | sed -n '/<main>:/,/^$$/p'

dis: $(TARGET).elf
	$(OBJDUMP) -d --no-show-raw-insn $(TARGET).elf | sed -n '1,140p'

# 裸机没有守卫页，栈溢出不报错 —— 只能自己量（见 book-notes/7.4-栈帧.md）
check-stack:
	$(CC) $(CFLAGS) -fstack-usage -c main.c -o /tmp/gpio-main.o
	@cat /tmp/gpio-main.su

.PHONY: regs dis check-stack probe-ports read-ports
