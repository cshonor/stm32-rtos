# Makefile —— stm32/03-gpio-blink
#
# 目标：把 NUCLEO-F103RB 的 LD2（PA5）点起来，并用调试器"读回"证明它真的在闪。
#
# 工具链与 stm32/00、01 完全一致（clang + ld.lld + llvm-*，不用 arm-none-eabi-gcc）：
#   前置：export PATH=/Users/a0000/micromamba/envs/cdev/bin:$PATH
#
# 常用目标：
#   make          构建（产出 blink_gpio.elf / .bin + 段大小）
#   make flash    烧进板子并复位运行（openocd + ST-Link）
#   make probe    ★ 只读探测：halt 后把检测点变量读回来（不改 Flash）
#   make gdb      用 gdb 连上去，源码级断点 + 单步（书 3.6 / 3.7）
#   make regs     dump GPIOA 的 CRL/CRH/IDR/ODR/BSRR 反汇编，看每条 C 语句几条指令
#   make clean

CC      := clang
LD      := ld.lld
OBJCOPY := llvm-objcopy
OBJDUMP := llvm-objdump
READELF := llvm-readelf
SIZE    := llvm-size
NM      := llvm-nm

OPENOCD := $(HOME)/.local/xpack-openocd-0.12.0-7/bin/openocd
OCD_CFG := ../02-libopencm3/openocd/f103rb.cfg
GDB     := $(HOME)/.local/arm-gnu-toolchain-14.2.rel1-darwin-arm64-arm-none-eabi/bin/arm-none-eabi-gdb

TARGET  := blink_gpio

# --target=armv7m-none-eabi : Cortex-M3 的 ARMv7-M（Thumb-2）
# -ffreestanding            : 没有 libc、没有 OS，别指望 printf/memcpy
# -fno-common               : 老 C 的"暂定定义"规则会和链接器捉迷藏，关掉更清楚
# -ffunction/ -fdata-sections + --gc-sections : 没被引用的代码/数据别进 Flash
# -fno-unwind-tables        : armv7m 上 LLVM 默认塞 .ARM.exidx，靠它尽量压掉
CFLAGS  := --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb \
           -ffreestanding -fno-builtin -fno-common \
           -Wall -Wextra -Os -g \
           -ffunction-sections -fdata-sections \
           -fno-unwind-tables -fno-asynchronous-unwind-tables

ASFLAGS := --target=armv7m-none-eabi -mcpu=cortex-m3 -mthumb -g

LDFLAGS := -T linker.ld --gc-sections

.PHONY: all clean flash probe probe-ports read-ports regs dis size symbols check-stack gdb

all: $(TARGET).bin size

# ---------------------------------------------------------------- 构建
startup_s.o: startup.S
	$(CC) $(ASFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: startup_s.o main.o linker.ld
	$(LD) $(LDFLAGS) -Map=$(TARGET).map -o $@ startup_s.o main.o

# --- 探针程序：单独一个可执行文件，用来"量"时钟未开时的寄存器行为 ---
# 它和主程序不是一回事：主程序点灯，探针程序只读、只回答"会发生什么"。
PROBE := portprobe

$(PROBE).elf: startup_s.o portprobe.o linker.ld
	$(LD) $(LDFLAGS) -Map=$(PROBE).map -o $@ startup_s.o portprobe.o

# 烧探针程序（会覆盖主程序，跑完停在死循环）
probe-ports: $(PROBE).bin
	$(OPENOCD) -f $(OCD_CFG) \
	  -c "program $(PROBE).bin 0x08000000 verify reset exit"

# 读探针结果（先 make probe-ports，再 make read-ports）
read-ports:
	@echo "=== 变量地址 ==="
	@$(NM) -n --print-size $(PROBE).elf | grep -E "stage|c_|b_|d_"
	@echo "=== 读回 ==="
	$(OPENOCD) -f $(OCD_CFG) \
	  -c "init" -c "halt" -c "wait_halt 1000" \
	  -c "mdw 0x20000000 28" -c "reg pc" \
	  -c "shutdown"

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

size: $(TARGET).elf
	@$(SIZE) -A $(TARGET).elf | sed -n '1,9p'
	@echo "--- 镜像文件 ---"
	@ls -l $(TARGET).bin | awk '{print "  "$9" = "$5" 字节"}'

# ---------------------------------------------------------------- 烧录
# verify 会逐字节比对 Flash 与 .bin，reset 后直接开始跑
flash: $(TARGET).bin
	$(OPENOCD) -f $(OCD_CFG) \
	  -c "program $(TARGET).bin 0x08000000 verify reset exit"

# ---------------------------------------------------------------- 只读探测
# ★ 这是本目录的核心验证手段：
#   halt 之后程序停在原地，LED 保持当前状态，然后把检测点读回来。
#   注意：halt 期间软件不再写 BSRR，所以 ODR 会"冻"在当前值——
#   想确认它在变，就连跑两次看数值是否不同。
probe:
	$(OPENOCD) -f $(OCD_CFG) \
	  -c "init" -c "halt" -c "wait_halt 1000" \
	  -c "echo {=== 向量表 @0x08000000 ===}" -c "mdw 0x08000000 4" \
	  -c "echo {=== RCC_APB2ENR @0x40021018（应=0x4）===}" -c "mdw 0x40021018 1" \
	  -c "echo {=== GPIOA_CRL / CRH / IDR / ODR / BSRR ===}" \
	  -c "mdw 0x40010800 6" \
	  -c "echo {=== 观测点变量 @0x20000000 ===}" -c "mdw 0x20000000 24" \
	  -c "echo {=== 寄存器 ===}" -c "reg pc" -c "reg msp" \
	  -c "shutdown"

# ---------------------------------------------------------------- 其它
# 书 3.4「探索构建过程」：看每条 C 语句被编成几条指令
regs: $(TARGET).elf
	$(OBJDUMP) -d --no-show-raw-insn $(TARGET).elf | sed -n '/<main>:/,/^$$/p'

dis: $(TARGET).elf
	$(OBJDUMP) -d --no-show-raw-insn $(TARGET).elf | sed -n '1,140p'

symbols: $(TARGET).elf
	$(NM) -n --print-size $(TARGET).elf

sections: $(TARGET).elf
	$(READELF) -S $(TARGET).elf

# 裸机没有守卫页，栈溢出不报错 —— 只能自己量（见 book-notes 3.x）
check-stack:
	$(CC) $(CFLAGS) -fstack-usage -c main.c -o /tmp/gpio-main.o
	@cat /tmp/gpio-main.su

# 书 3.6 / 3.7：调试应用程序 / 逐步执行程序
# 手工跑法（两个终端）：
#   终端 A:  $(OPENOCD) -f $(OCD_CFG)
#   终端 B:  $(GDB) $(TARGET).elf
#              (gdb) target remote :3333
#              (gdb) monitor reset halt
#              (gdb) break main
#              (gdb) continue
#              (gdb) next / step / info registers / x/8xw 0x40010800
gdb: $(TARGET).elf
	@echo "gdb 用法见本 Makefile 注释（需要另开一个终端跑 openocd）"

clean:
	rm -f *.o *.elf *.bin *.map *.su
