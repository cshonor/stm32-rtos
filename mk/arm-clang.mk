# =============================================================================
# mk/arm-clang.mk —— 裸机 clang 构建规则（全仓库共用）
#
# 解决的问题：`01-stm32/00`、`01-stm32/01`、`01-stm32/03`、`labs/*` 每个目录都把同一份
# CFLAGS / LDFLAGS / 规则抄了一遍，改一个编译选项要改五处；烧录和调试的命令
# 里还硬编码了 `$(HOME)/.local/xpack-openocd-<版本>/…` 这种"只在这台机器上成立"
# 的路径。这份文件把这两件事收拢到一处。
#
# 用法 —— lab 的 Makefile 只需要写这四行：
#
#     BOARD  ?= f103rb
#     TARGET := blink
#     SRCS   := startup.S main.c
#     include ../../mk/arm-clang.mk
#
# 之后自动获得（不写一行规则）：
#
#     make            编译 + 链接 + objcopy，并打印体积账单
#     make size       各段明细 + .bin 实际字节数
#     make dump       反汇编（llvm-objdump -d）
#     make sections   段表 / 程序头
#     make symbols    符号表（地址升序，带 size）
#     make flash      编程 + 校验 + 复位 + 退出（要插板子）
#     make probe      halt 后读回向量表与寄存器（只读，不改 Flash）
#     make openocd    前台常驻，占住 :3333
#     make gdb        连上 :3333，在 Reset_Handler 停下
#     make clean
#
# 变量（都可覆盖）：
#     BOARD      板子名 = boards/ 下的文件名（不带 .mk）：f103rb / f103c8t6 / f407zg
#     TARGET     产物名，默认取当前目录名
#     SRCS       源文件列表，默认 *.c *.S 全收；.S 走 ASFLAGS，.c 走 CFLAGS
#     CFLAGS / ASFLAGS / LDFLAGS   在 include 之前 += 可以追加（如 -fstack-usage）
#     LLVM_BIN / GCC_ARM_BIN / OPENOCD / OPENOCD_SCRIPTS / PYTHON
#                见 mk/locate-tools.mk；不在 PATH 里时显式给
#     PROBE_EXTRA 追加到 `make probe` 里的额外 openocd -c 命令（本 lab 特有的观测点）
#     额外目标    在 include 之后照常写 `目标: 依赖`，互不冲突
#
# 板级差异（CPU / 内存布局 / OpenOCD 配置 / LED 引脚）全部在 boards/<BOARD>.mk，
# 这里不出现任何具体芯片名。
# =============================================================================

MK_DIR    := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(MK_DIR)/..)

include $(REPO_ROOT)/mk/locate-tools.mk

# -----------------------------------------------------------------------------
# 板级
# -----------------------------------------------------------------------------
ifeq ($(strip $(BOARD)),)
$(error 没指定 BOARD。在 Makefile 里写一行 `BOARD ?= f103rb`，可选值为 $(notdir $(basename $(wildcard $(REPO_ROOT)/boards/*.mk))))
endif

ifneq ($(wildcard $(REPO_ROOT)/boards/$(BOARD).mk),)
include $(REPO_ROOT)/boards/$(BOARD).mk
else
$(error 找不到 boards/$(BOARD).mk。可选板子：$(notdir $(basename $(wildcard $(REPO_ROOT)/boards/*.mk))))
endif

# -----------------------------------------------------------------------------
# 目标与源文件
# -----------------------------------------------------------------------------
TARGET ?= $(notdir $(CURDIR))
SRCS   ?= $(wildcard *.c *.S)
OBJS   := $(addsuffix .o,$(basename $(SRCS)))

OPT ?= -Os

# 每一行注释为什么在，见 01-stm32/03-gpio-blink/Makefile 的历史版本与
# 01-stm32/book-notes/11-linker；这里只留结论。
CFLAGS  += --target=$(BOARD_TRIPLE) -mcpu=$(BOARD_CPU) -mthumb $(BOARD_CFLAGS) \
           -ffreestanding -fno-builtin -fno-common \
           -Wall -Wextra $(OPT) -g \
           -ffunction-sections -fdata-sections \
           -fno-unwind-tables -fno-asynchronous-unwind-tables

ASFLAGS += --target=$(BOARD_TRIPLE) -mcpu=$(BOARD_CPU) -mthumb $(BOARD_CFLAGS) -g

LDFLAGS += -T linker.ld --gc-sections

.PHONY: all clean size dump sections symbols flash probe openocd gdb

all: $(TARGET).bin size

# -----------------------------------------------------------------------------
# 规则
# -----------------------------------------------------------------------------
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(ASFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS) linker.ld
	$(LD) $(LDFLAGS) -Map=$(TARGET).map -o $@ $(OBJS)

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# -----------------------------------------------------------------------------
# 观察
# -----------------------------------------------------------------------------
size: $(TARGET).elf
	@echo "=== 段明细（$(BOARD_NAME)）==="
	@$(SIZE) -A $< | sed -n '1,12p'
	@echo "--- 镜像文件 ---"
	@ls -l $(TARGET).bin 2>/dev/null | awk '{print "  "$$9" = "$$5" 字节"}'
	@echo "--- 与 Flash 容量的比例 ---"
	@printf "  %s / %s\n" "$$(ls -l $(TARGET).bin | awk '{print $$5}')" "$(BOARD_FLASH_SIZE)"

dump: $(TARGET).elf
	$(OBJDUMP) -d --no-show-raw-insn $< | sed -n '1,140p'

sections: $(TARGET).elf
	$(OBJDUMP) -h $<

symbols: $(TARGET).elf
	$(NM) -n --print-size $<

# -----------------------------------------------------------------------------
# 烧录 / 调试
#   烧的是 .bin（纯字节流，必须显式给 Flash 起始地址），
#   调的是 .elf（带符号表和 DWARF，gdb 靠它把地址翻译成 源码:行号）。
#   两者同一次链接产出，用途不同，别混用 —— 见 01-stm32/book-notes/02-ide/2.2。
# -----------------------------------------------------------------------------
flash: $(TARGET).bin
	$(OPENOCD_CMD) -f $(BOARD_OPENOCD_CFG) \
	  -c "program $(TARGET).bin $(BOARD_FLASH_ORIGIN) verify reset exit"

# 只读探测：halt 之后程序停在原地，Flash 不变。
# 想知道"它还在跑"就连跑两次看变量数值是否不同。
#
# 各 lab 可以在 include 之后追加自己的观测点（默认读向量表 + pc/msp）：
#     PROBE_EXTRA := -c "echo {=== RCC ===}" -c "mdw 0x40021018 1"
# 这样 `make probe` 在每个目录里读的都是"这个实验该看的东西"。
probe:
	$(OPENOCD_CMD) -f $(BOARD_OPENOCD_CFG) \
	  -c "init" -c "halt" -c "wait_halt 1000" \
	  -c "echo {=== 向量表 @$(BOARD_FLASH_ORIGIN)（[0]=栈顶 [1]=Reset_Handler）===}" \
	  -c "mdw $(BOARD_FLASH_ORIGIN) 4" \
	  $(PROBE_EXTRA) \
	  -c "echo {=== 寄存器 ===}" -c "reg pc" -c "reg msp" \
	  -c "shutdown"

openocd:
	$(OPENOCD_CMD) -f $(BOARD_OPENOCD_CFG)

# 需要另一个终端先跑 `make openocd`（或直接用 tools/dbg.sh，它自动开）
# 断点默认打在 Reset_Handler：比停在 main 更有用，因为能看到整段启动序列。
# 想换就在 lab 里写 GDB_BREAK := main。
GDB_BREAK ?= Reset_Handler

gdb: $(TARGET).elf
	$(GDB) $(TARGET).elf \
	  -ex "target extended-remote :3333" \
	  -ex "monitor reset halt" \
	  -ex "break $(GDB_BREAK)" \
	  -ex "continue"

clean:
	$(RM) -f *.o *.elf *.bin *.hex *.map *.su
