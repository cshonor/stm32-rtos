/* linker.ld —— 谁决定代码落在哪块存储器
 *
 * 由 tools/newlab.sh 依据 boards/@BOARD@.mk 生成，占位符已替换成实际数值：
 *   @BOARD_NAME@ : Flash @FLASH_ORIGIN@ / @FLASH_SIZE@，SRAM @RAM_ORIGIN@ / @RAM_SIZE@
 *
 * C 语言的视角：符号有地址，函数可以调用，变量可以读写。
 * 没人告诉 CPU 这些地址从哪来 —— 是链接脚本说的。
 * 换句话说：链接脚本 = 这枚芯片的物理内存地图（RM0008 第 4 章 Memory map）。
 * 逐段解释见 01-stm32/book-notes/11-linker。
 */

ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = @FLASH_ORIGIN@, LENGTH = @FLASH_SIZE@
    RAM   (rwx) : ORIGIN = @RAM_ORIGIN@,   LENGTH = @RAM_SIZE@
}

/* 栈顶 = SRAM 末尾，栈向下生长；这个值被向量表第 0 个字引用 */
_estack = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    /* 代码 + 只读数据留在 Flash，就地执行（XIP）。
     * KEEP 防止 --gc-sections 把向量表当"没人引用"删掉。 */
    .text : {
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    /* .data 有初值：运行地址在 RAM，加载地址(LOADADDR)在 Flash。
     * _sidata 就是那个 Flash 侧的地址，由 startup.c 的 Reset_Handler 搬。 */
    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH
    _sidata = LOADADDR(.data);

    /* .bss 无初值（C 标准要求为 0）：只占 RAM，不占 Flash */
    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* 编译期自检：Flash 放不下就报错，别烧进去才发现截断 */
    .flash_overflow_check : {
        ASSERT(. <= ORIGIN(FLASH) + LENGTH(FLASH), "FLASH overflow!")
    } > FLASH

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        /* .ARM.exidx 是异常/栈回溯表：clang 在 armv7m 上默认生成，
         * 实测 -fno-unwind-tables 也去不掉（每个 C 函数 8 字节）。
         * 纯 C 裸机不需要它，这里直接丢；要用栈回溯就得改成收进 .text。 */
        *(.ARM.exidx*)
    }
}
