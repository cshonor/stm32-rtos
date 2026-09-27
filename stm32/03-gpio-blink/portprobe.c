/* portprobe.c —— stm32/03-gpio-blink 的探针程序（不是教学主程序，是"量仪器"）
 *
 * 目的：用真机回答两个书上没写清、但每个人都会撞上的问题：
 *
 *   Q1 「不开外设时钟就去读/写它的寄存器，会怎样？」
 *       —— 会静默失败（写进去没了、读出来是 0）？还是会 HardFault？还是读写都正常？
 *         三种说法网上都有。这里用一个 stage 面包屑把它测死。
 *
 *   Q2 「GPIO 复位后默认是什么状态？」
 *       —— 手册写的复位值和真机读到的有时不一样（比如 PA13/PA14/PA15 因为
 *          SWD/JTAG 调试口的关系不是标准的 0x44444444）。必须实测。
 *
 *   Q3 板载按键 B1 在 PC13，松手时到底读到 0 还是 1？
 *       —— 取决于板上的上下拉电阻，看原理图不如直接读。
 *
 * 做法：每一步都先写 stage（放 .noinit，不被启动代码清零），
 *       如果程序在中途 HardFault，断电后读 stage 就知道卡在第几步。
 *
 * 火焰：本程序不改任何引脚配置，只读 + 往 GPIOC_ODR 写一个明显的模式。
 *       跑完停在死循环，等调试器来读变量。
 */

#include <stdint.h>

#define RCC_APB2ENR   (*(volatile uint32_t *)0x40021018u)
#define RCC_IOPAEN    (1u << 2)
#define RCC_IOPBEN    (1u << 3)
#define RCC_IOPCEN    (1u << 4)
#define RCC_IOPDEN    (1u << 5)

/* 每个端口一组：CRL(0x00) CRH(0x04) IDR(0x08) ODR(0x0C) */
#define GPIOC_BASE    0x40011000u
#define GPIOC_CRL     (*(volatile uint32_t *)(GPIOC_BASE + 0x00u))
#define GPIOC_IDR     (*(volatile uint32_t *)(GPIOC_BASE + 0x08u))
#define GPIOC_ODR     (*(volatile uint32_t *)(GPIOC_BASE + 0x0Cu))

#define GPIOB_CRL     (*(volatile uint32_t *)0x40010C00u)
#define GPIOB_IDR     (*(volatile uint32_t *)0x40010C08u)

#define GPIOD_BASE    0x40011400u
#define GPIOD_CRL     (*(volatile uint32_t *)(GPIOD_BASE + 0x00u))
#define GPIOD_CRH     (*(volatile uint32_t *)(GPIOD_BASE + 0x04u))
#define GPIOD_IDR     (*(volatile uint32_t *)(GPIOD_BASE + 0x08u))
#define GPIOD_ODR     (*(volatile uint32_t *)(GPIOD_BASE + 0x0Cu))

/* startup.S 的 Reset_Handler 会往 boot_stage 写 1/2/3（启动面包屑），
 * 所以这个符号必须存在，否则链接时报 undefined symbol。 */
__attribute__((section(".noinit"))) volatile uint32_t boot_stage;

/* 本探针程序自己的步骤标记（同样放 .noinit，不被清零） */
__attribute__((section(".noinit"))) volatile uint32_t stage;

/* --- Q1：时钟关闭期间的读写回声 --- */
volatile uint32_t c_crl_off;      /* GPIOC_CRL，时钟关时读 */
volatile uint32_t c_idr_off;      /* GPIOC_IDR，时钟关时读 */
volatile uint32_t c_odr_echo;     /* 时钟关时写 0xA5A5A5A5 后立刻读回 */
volatile uint32_t c_crl_on;       /* GPIOC_CRL，开时钟后读 */
volatile uint32_t c_odr_on;       /* GPIOC_ODR，开时钟后读（那个写的值还在吗？）*/
volatile uint32_t c_idr_on;       /* GPIOC_IDR，开时钟后读（按键松手态）*/

/* --- Q2：对照组，GPIOB（同样没被碰过） --- */
volatile uint32_t b_crl_off;
volatile uint32_t b_crl_on;

/* --- Q2b：GPIO D —— 从头到尾没人碰过，读它的"出厂复位值" --- */
volatile uint32_t d_crl;          /* 0x40011400 */
volatile uint32_t d_crh;          /* 0x40011404 */
volatile uint32_t d_idr;          /* 0x40011408 */
volatile uint32_t d_odr;          /* 0x4001140C */

int main(void)
{
    stage = 1;
    RCC_APB2ENR |= RCC_IOPAEN;        /* 只开 GPIOA —— B/C/D 保持关着 */

    /* ---------- 时钟关着：读 ---------- */
    stage = 2;
    c_crl_off = GPIOC_CRL;
    stage = 3;
    c_idr_off = GPIOC_IDR;
    stage = 4;
    b_crl_off = GPIOB_CRL;

    /* ---------- 时钟关着：写，然后立刻读回（回声测试）---------- */
    stage = 5;
    GPIOC_ODR = 0xA5A5A5A5u;
    stage = 6;
    c_odr_echo = GPIOC_ODR;

    /* ---------- 打开 B/C/D 的时钟 ---------- */
    stage = 7;
    RCC_APB2ENR |= RCC_IOPBEN | RCC_IOPCEN | RCC_IOPDEN;

    /* ---------- 时钟开着：再读一遍同一批寄存器 ---------- */
    stage = 8;
    c_crl_on = GPIOC_CRL;
    stage = 9;
    c_odr_on = GPIOC_ODR;             /* 关键：时钟关上时写的 0xA5A5A5A5 生效了吗 */
    stage = 10;
    c_idr_on = GPIOC_IDR;             /* 板载按键 B1 在 PC13 */
    stage = 11;
    b_crl_on = GPIOB_CRL;

    /* ---------- GPIOD：整个程序没碰过的端口 ---------- */
    stage = 12;
    d_crl = GPIOD_CRL;
    d_crh = GPIOD_CRH;
    d_idr = GPIOD_IDR;
    d_odr = GPIOD_ODR;

    stage = 13;
    for (;;) {
        __asm__ volatile("nop");
    }
}
