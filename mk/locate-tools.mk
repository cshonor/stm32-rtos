# =============================================================================
# mk/locate-tools.mk —— 「工具在哪」只回答这一个问题
#
# 设计原则：**make 里不做搜索，只做覆盖。**
#   搜索（翻 ~/.local、C:\Program Files、micromamba envs…）交给 tools/env.sh，
#   因为那需要 shell；而 make 的 $(shell) 在 Windows 原生 make（无 sh）上不可靠，
#   会出现"在 Mac 上好好的、在 Windows 上静默拿到空字符串"这种最难查的错。
#
#   所以这里的契约是：**PATH 里有什么就用什么**，要用不在 PATH 里的工具时，
#   显式给变量（命令行覆盖或 include 之前赋值）：
#       make LLVM_BIN=/Users/a0000/micromamba/envs/cdev/bin
#       make OPENOCD=$HOME/.local/xpack-openocd-0.12.0-7/bin/openocd
#   或者更省事：
#       source tools/env.sh --export     # 自动把探测到的目录加进 PATH
#
# 所有变量都用 ?=，所以 lab 的 Makefile 在 include 之前赋值即可覆盖。
# =============================================================================

# --- LLVM 工具链（clang / ld.lld / llvm-objcopy …）---------------------------
# LLVM_BIN 指向包含 clang 的 bin 目录；留空则直接用 PATH 上的裸命令名。
LLVM_BIN ?=

ifneq ($(LLVM_BIN),)
  CC      ?= $(LLVM_BIN)/clang
  LD      ?= $(LLVM_BIN)/ld.lld
  OBJCOPY ?= $(LLVM_BIN)/llvm-objcopy
  OBJDUMP ?= $(LLVM_BIN)/llvm-objdump
  READELF ?= $(LLVM_BIN)/llvm-readelf
  SIZE    ?= $(LLVM_BIN)/llvm-size
  NM      ?= $(LLVM_BIN)/llvm-nm
else
  CC      ?= clang
  LD      ?= ld.lld
  OBJCOPY ?= llvm-objcopy
  OBJDUMP ?= llvm-objdump
  READELF ?= llvm-readelf
  SIZE    ?= llvm-size
  NM      ?= llvm-nm
endif

# --- GNU Arm 工具链（只有调试才需要；libopencm3 那条轨另算）-------------------
# GCC_ARM_BIN 指向包含 arm-none-eabi-gdb 的 bin 目录；留空则用 PATH。
GCC_ARM_BIN ?=

ifneq ($(GCC_ARM_BIN),)
  GNU_PREFIX ?= $(GCC_ARM_BIN)/arm-none-eabi-
else
  GNU_PREFIX ?= arm-none-eabi-
endif

GDB ?= $(GNU_PREFIX)gdb

# --- OpenOCD ------------------------------------------------------------------
# OPENOCD_SCRIPTS：xpack 这类"解压即用"的发行版必须给（-s 指向它的 scripts 目录）；
#                  brew / apt / winget 装的版本自带搜索路径，留空即可。
OPENOCD         ?= openocd
OPENOCD_SCRIPTS ?=

# 路径可能含空格（Windows 的 "C:\Program Files\..."），所以拼命令时一律带引号，
# 各 lab 直接用 $(OPENOCD_CMD)，不要再自己拼 "$(OPENOCD) $(OCD_S_FLAG)"。
ifneq ($(strip $(OPENOCD_SCRIPTS)),)
  OCD_S_FLAG := -s "$(strip $(OPENOCD_SCRIPTS))"
else
  OCD_S_FLAG :=
endif

OPENOCD_CMD := "$(OPENOCD)" $(OCD_S_FLAG)

# --- 其它 ---------------------------------------------------------------------
# check_vectors.py 这类主机侧断言脚本要它；/usr/bin/python3 在 macOS 上
# 会弹 Xcode 许可协议，所以用 conda/brew 的 python3 时显式覆盖。
PYTHON ?= python3
