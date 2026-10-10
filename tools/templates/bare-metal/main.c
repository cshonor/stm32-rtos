/* main.c —— 裸机点灯骨架（由 tools/newlab.sh 生成）
 *
 * 上电 → Reset_Handler → main() → 板载 LED 闪烁。
 * 不依赖 HAL / CMSIS / 任何库，只有 RM0008 里抄下来的几个寄存器地址。
 *
 * ⚠ 这个骨架按 **STM32F1 的 GPIO 写法**（CRL/CRH 两位域配模式）。
 *   F4/F7 的 GPIO 换成了 MODER / OTYPER / OSPEEDR，led_init() 要重写，
 *   但 led_on/led_off 用的 BSRR 在 F1..F4 是一致的。
 */

typedef unsigned int u32;

/* =========================================================================
 * 换板子就改这一段 —— 三个数而已。
 *   NUCLEO-F103RB      LD2  : 端口 A，pin 5 ，高电平点亮
 *   Blue Pill F103C8T6 LED  : 端口 C，pin 13，低电平点亮
 *   探索者 F407        LED0 : 端口 F，pin 9 ，低电平点亮
 * ========================================================================= */
#define LED_BASE        0x40011000u   /* GPIO 基址：A=0x40010800 B=0x40010C00 C=0x40011000 … */
#define LED_PIN         13u           /* 0..15 */
#define LED_ACTIVE_LOW  1             /* 1 = 低电平点亮 */
#define LED_RCC_BIT     4u            /* APB2ENR 里的端口使能位：A=2 B=3 C=4 D=5 E=6 F=7 */

#define RCC_BASE        0x40021000u
#define RCC_APB2ENR     (*(volatile u32 *)(RCC_BASE + 0x18u))

/* CRL 管 pin0..7，CRH 管 pin8..15，每个引脚占 4 位。 */
#define LED_CR          (*(volatile u32 *)(LED_BASE + ((LED_PIN < 8u) ? 0x00u : 0x04u)))
#define LED_CR_SHIFT    ((LED_PIN % 8u) * 4u)

/* BSRR 是 32 位：低 16 位写 1 置位，高 16 位写 1 清零。
 * 用它而不是读改写 ODR：单周期原子写，不会被中断撕开。
 * （F1 另有 BRR 专管清零，但 BSRR 的高 16 位在 F1..F4 都通用，所以只用 BSRR。） */
#define PIN_MASK        (1u << LED_PIN)
#define PIN_SET()       (*(volatile u32 *)(LED_BASE + 0x10u) = PIN_MASK)
#define PIN_CLR()       (*(volatile u32 *)(LED_BASE + 0x10u) = (PIN_MASK << 16))

#if LED_ACTIVE_LOW
#  define LED_ON()   PIN_CLR()
#  define LED_OFF()  PIN_SET()
#else
#  define LED_ON()   PIN_SET()
#  define LED_OFF()  PIN_CLR()
#endif

/* 软件延时：参数必须是 volatile，否则 -Os 会把 while(n--) 优化成 while(1)。
 * 这只是粗略延时（复位后跑的是 HSI，F1 上是 8MHz）；
 * 精确计时要靠 SysTick —— 见 01-stm32/book-notes/19-systick-and-timer。 */
static void delay(volatile u32 n)
{
    while (n != 0u) {
        n = n - 1u;
    }
}

static void led_init(void)
{
    /* F1 上外设时钟默认是关的：不使能就写寄存器，等于把值扔进垃圾桶。 */
    RCC_APB2ENR |= (1u << LED_RCC_BIT);

    /* 通用推挽输出 + 输出模式 2MHz = CNF 00 / MODE 10 → 0x2 */
    LED_CR &= ~(0xFu << LED_CR_SHIFT);
    LED_CR |=  (0x2u << LED_CR_SHIFT);
}

int main(void)
{
    led_init();

    for (;;) {
        LED_ON();
        delay(400000u);
        LED_OFF();
        delay(400000u);
    }
}
