# Makefile —— @TARGET@
#
# 由 tools/newlab.sh 生成。所有的编译选项、链接规则、烧录/调试命令
# 都在 mk/arm-clang.mk 里，这里只声明"我是谁、用什么板子"。
#
#     make            编译 + 链接 + objcopy + 体积账单
#     make flash      烧录（要插板子）
#     make probe      halt 后只读回读
#     make dbg        提示怎么起 openocd + gdb
#     make BOARD=f103c8t6 …   临时换板子

BOARD  ?= @BOARD@
TARGET := @TARGET@
SRCS   := startup.c main.c

include @MK_REL@/mk/arm-clang.mk
