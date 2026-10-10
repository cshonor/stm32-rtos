# =============================================================================
# boards/f407zg.mk —— 正点原子 F407 探索者（STM32F407ZGT6）
#
# 与 F103 的两处结构性差异，写在这里免得每个 lab 重踩：
#   1. 内核是 Cortex-M4F（带 FPU）→ 可以用硬件浮点，__aeabi_* 软件浮点不再是必选项
#   2. 上电默认跑内部 HSI 16MHz，不是满血 168MHz → 要跑满得自己配 PLL
# =============================================================================

BOARD_NAME   := 正点原子 F407 探索者（STM32F407ZGT6）
BOARD_DEVICE := stm32f407zg

BOARD_CPU    := cortex-m4
BOARD_TRIPLE := armv7m-none-eabi

# FPU 开关：默认走软浮点（和 F103 的脚本保持一致，便于对照）。
# 要用硬件浮点，把这行改成：-mfloat-abi=hard -mfpu=fpv4-sp-d16
# 注意：开了之后中断服务函数会真的去碰 s0/s1，现场保护和栈对齐的要求都变了
#       （01-stm32/01-bare-metal 的 make check-isr 有两个内核的对照输出）。
BOARD_CFLAGS :=

# 1MB Flash / 128KB SRAM + 64KB CCM（CCM 只能放数据，且不能被 DMA 访问，
# 所以链接脚本里先只用 SRAM，别顺手把 CCM 也并进来）。
BOARD_FLASH_ORIGIN := 0x08000000
BOARD_FLASH_SIZE   := 1M
BOARD_RAM_ORIGIN   := 0x20000000
BOARD_RAM_SIZE     := 128K

# LED0 = PF9，LED1 = PF10，都是**低电平点亮**。
BOARD_LED := PF9 / PF10（低电平点亮）

# 探索者板上的 ST-Link 是排针外接的（不是板载调试器），走 generic 配置。
BOARD_OPENOCD_CFG := $(REPO_ROOT)/boards/openocd/f407zg-stlink.cfg
