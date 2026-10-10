/* =============================================================================
 * tools/selftest/min.c —— 工具台自检用的最小裸机程序
 *
 * 唯一的要求是「能被完整走完 C → .o → .elf → .bin 四步」，不是为了跑到板子上。
 * 所以它刻意凑齐了三样最容易在链接期炸出来的东西：
 *     g_data  → .data 段（有初值，加载地址在 Flash、运行地址在 RAM）
 *     g_bss   → .bss 段（无初值，不占 Flash）
 *     REG     → 一个 MMIO 地址常量，顺带验证编译器没有把它优化没
 *
 * 全部用 volatile，原因见 01-stm32/00-toolchain-clang 的第一条实测：
 * 普通指针读寄存器会被编译器搬出循环，而寄存器是硬件在改。
 * ========================================================================== */

volatile unsigned int g_data = 0xA5A5A5A5u;   /* .data：4 字节在 Flash 里当初值 */
volatile unsigned int g_bss;                   /* .bss ：只占 RAM */

static volatile unsigned int *const REG = (volatile unsigned int *)0x4001100Cu;

int main(void);

void Reset_Handler(void) {
    *REG = g_data;
    g_bss++;
    main();
    for (;;) { }
}

int main(void) {
    for (;;) {
        g_data++;
        *REG = g_data;
    }
}
