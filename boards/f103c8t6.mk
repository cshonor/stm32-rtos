# =============================================================================
# boards/f103c8t6.mk —— Blue Pill / 最小系统板（STM32F103C8T6）
#
# 和 F103RB 同一颗内核、同一张地址表，差别只在 Flash 容量和板载 LED。
# 这类板子**没有板载调试器**，要外接一根 USB 转 SWD 的 ST-Link，
# 所以 OpenOCD 走 generic 配置（interface + target 分开写）而不是官方板卡脚本。
# =============================================================================

BOARD_NAME   := STM32F103C8T6（Blue Pill）
BOARD_DEVICE := stm32f103c8

BOARD_CPU    := cortex-m3
BOARD_TRIPLE := armv7m-none-eabi
BOARD_CFLAGS :=

# 常说的"64K"指官方标称 64KB Flash（实际不少批次有 128K，但别依赖它）。
# SRAM 仍是 20K。
BOARD_FLASH_ORIGIN := 0x08000000
BOARD_FLASH_SIZE   := 64K
BOARD_RAM_ORIGIN   := 0x20000000
BOARD_RAM_SIZE     := 20K

# PC13 是**低电平点亮**：BSRR = 1<<13 是灭，1<<(13+16) 是亮。
# 从 NUCLEO 的 PA5 换到这块板子，代码里第一件要改的就是这里。
BOARD_LED := PC13（板载 LED，低电平点亮）

BOARD_OPENOCD_CFG := $(REPO_ROOT)/boards/openocd/generic-stlink-f103.cfg
