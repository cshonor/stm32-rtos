/* =============================================================================
 * tools/selftest/min.ld —— 工具台自检用的最小链接脚本
 *
 * 故意比 labs/ 里的正式脚本简单：只要能把 .text / .data / .bss 三段落下去，
 * 一次链接就会把「链接脚本语法、lld 能不能吃 GNU 脚本、段地址算得对不对」
 * 全部暴露出来。
 *
 * 地址与 boards/f103rb.mk 一致，但容量取小值（16K/4K）——自检产物只有几百字节，
 * 不需要真板子的容量。
 * ========================================================================== */

ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 16K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 4K
}

_estack = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .text : {
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    .data : {
        . = ALIGN(4);
        *(.data*)
        . = ALIGN(4);
    } > RAM AT > FLASH

    .bss : {
        . = ALIGN(4);
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
    } > RAM
}
