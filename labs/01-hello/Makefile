# Makefile —— labs/01-hello
#
# 工具台改造示范：这个文件曾经把 CC/LD/OBJCOPY、CFLAGS、LDFLAGS 和规则全抄了
# 一遍（每个 lab 一份，改一个选项要改五处），现在已经收拢进 mk/arm-clang.mk，
# 这里只剩「我是谁、用什么板子」。
#
#     make          编译 + 链接 + objcopy + 体积账单
#     make flash    烧录（Blue Pill + 外接 ST-Link）
#     make probe    halt 后只读回读（向量表 + pc/msp）
#     make dbg      提示怎么起 openocd + gdb；或直接用 tools/dbg.sh hello.elf
#     make clean
#
# 前置（工具不在 PATH 上时）：
#     source tools/env.sh --export

BOARD  ?= f103c8t6
TARGET := hello
SRCS   := startup.c main.c

include ../../mk/arm-clang.mk
