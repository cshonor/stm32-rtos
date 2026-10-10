# =============================================================================
# boards/f103rb.mk —— NUCLEO-F103RB（ST 官方 Nucleo-64）
#
# 本仓库的主板：板载 ST-Link/V2-1，macOS 免驱、Windows 需装 ST-Link 驱动。
# 布局来自 01-stm32/01-bare-metal/linker.ld 的实测（RM0008 第 4 章 Memory map）。
# =============================================================================

BOARD_NAME   := NUCLEO-F103RB
BOARD_DEVICE := stm32f103rb

# Cortex-M3，无 FPU：所以浮点和 64 位除法会被编译器换成 __aeabi_* 调用
# （见 01-stm32/00-toolchain-clang 的 make check-libc）
BOARD_CPU    := cortex-m3
BOARD_TRIPLE := armv7m-none-eabi
BOARD_CFLAGS :=

# Flash 128K / SRAM 20K。栈顶 = 0x20000000 + 20K = 0x20005000，
# 这个值就是向量表第 0 个字，上电时硬件自己读进 MSP。
BOARD_FLASH_ORIGIN := 0x08000000
BOARD_FLASH_SIZE   := 128K
BOARD_RAM_ORIGIN   := 0x20000000
BOARD_RAM_SIZE     := 20K

BOARD_LED := PA5（LD2，高电平点亮）

BOARD_OPENOCD_CFG := $(REPO_ROOT)/boards/openocd/f103rb.cfg
