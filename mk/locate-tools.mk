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
# ⚠ 这些变量不能用 `?=`：GNU make 对 CC/LD 有内建默认值（CC=cc、LD=ld，
#   origin=default），而 `?=` 把"内建默认"也算"已定义"、静默不生效——
#   实测 LD 会落回 macOS 的 /usr/bin/ld（Mach-O 链接器），报
#   "unknown option: -T"（2026-11-10 复现于 labs/01-hello 与 03-gpio-blink）。
#   所以这里按 origin 兜底：只在【未定义 / 内建默认】时才赋我们的默认值；
#   命令行、环境变量、lab Makefile 在 include 前的赋值照常优先。
# LLVM_BIN 指向包含 clang 的 bin 目录；留空则直接用 PATH 上的裸命令名。
LLVM_BIN ?=

ifneq ($(LLVM_BIN),)
  ifneq ($(filter undefined default,$(origin CC)),)
    CC      := $(LLVM_BIN)/clang
  endif
  ifneq ($(filter undefined default,$(origin LD)),)
    LD      := $(LLVM_BIN)/ld.lld
  endif
  ifneq ($(filter undefined default,$(origin OBJCOPY)),)
    OBJCOPY := $(LLVM_BIN)/llvm-objcopy
  endif
  ifneq ($(filter undefined default,$(origin OBJDUMP)),)
    OBJDUMP := $(LLVM_BIN)/llvm-objdump
  endif
  ifneq ($(filter undefined default,$(origin READELF)),)
    READELF := $(LLVM_BIN)/llvm-readelf
  endif
  ifneq ($(filter undefined default,$(origin SIZE)),)
    SIZE    := $(LLVM_BIN)/llvm-size
  endif
  ifneq ($(filter undefined default,$(origin NM)),)
    NM      := $(LLVM_BIN)/llvm-nm
  endif
else
  ifneq ($(filter undefined default,$(origin CC)),)
    CC      := clang
  endif
  ifneq ($(filter undefined default,$(origin LD)),)
    LD      := ld.lld
  endif
  ifneq ($(filter undefined default,$(origin OBJCOPY)),)
    OBJCOPY := llvm-objcopy
  endif
  ifneq ($(filter undefined default,$(origin OBJDUMP)),)
    OBJDUMP := llvm-objdump
  endif
  ifneq ($(filter undefined default,$(origin READELF)),)
    READELF := llvm-readelf
  endif
  ifneq ($(filter undefined default,$(origin SIZE)),)
    SIZE    := llvm-size
  endif
  ifneq ($(filter undefined default,$(origin NM)),)
    NM      := llvm-nm
  endif
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
