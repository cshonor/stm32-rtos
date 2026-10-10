/* main.c —— 01-hello：我的第一段代码真的在芯片上跑
 *
 * 这是 00-toolchain-clang 之后的第一个"干净"实验。
 * 00 里混了一堆探针（wait_press_bad/good、libc-trap.c、反面教材），
 * 那是为了摸清工具链；本目录把它们全部剥掉，只留一件事：
 *
 *      上电 → Reset_Handler → main() → 板载 LED 以 1Hz 闪烁
 *
 * 板子：STM32F103C8T6（Blue Pill），板载 LED 接在 PC13，低电平点亮。
 * 工具链：clang + ld.lld，-ffreestanding -nostdlib，不依赖 HAL/CMSIS。
 */

typedef unsigned int  u32;
typedef unsigned char u8;

/* ---- 地址表（RM0008 抄下来的，就这几个数） ----------------------------
 * RCC   : 复位与时钟控制，基地址 0x4002_1000
 * GPIOC : 端口 C，基地址 0x4001_1000
 * 寄存器偏移：APB2ENR +0x18 / CRH +0x04 / ODR +0x0C / BSRR +0x10
 */
#define RCC_BASE      0x40021000u
#define GPIOC_BASE    0x40011000u

#define RCC_APB2ENR   (*(volatile u32 *)(RCC_BASE   + 0x18u))
#define GPIOC_CRH     (*(volatile u32 *)(GPIOC_BASE + 0x04u))
#define GPIOC_BSRR    (*(volatile u32 *)(GPIOC_BASE + 0x10u))

/* Blue Pill 的板载 LED：PC13，灌电流点亮（低电平亮）。
 * BSRR 是 32 位寄存器：写高 16 位清 0，写低 16 位置 1。
 *   BSRR =  (1<<13)   → PC13 = 1 → 灭
 *   BSRR =  (1<<29)   → PC13 = 0 → 亮（13+16=29）
 * 用 BSRR 而不是读改写 ODR，是因为它是单周期原子写，不会被中断撕。 */
#define LED_ON()   GPIOC_BSRR = (1u << (13u + 16u))
#define LED_OFF()  GPIOC_BSRR = (1u << 13u)

/* 软件延时：参数必须 volatile，否则 -Os 会把 while(n--) 优化成 while(1)。
 * 注意：这只是粗略延时，8MHz HSI 下约几百 ms；精确延时等 06-timer 用 SysTick。 */
static void delay(volatile u32 n)
{
    while (n != 0u) {
        n = n - 1u;
    }
}

int main(void)
{
    /* 1. 开 GPIOC 时钟：F1 上外设默认时钟是关的，不使能写寄存器等于扔进垃圾桶 */
    RCC_APB2ENR |= (1u << 4);            /* IOPCEN：IO 端口 C 时钟使能 */

    /* 2. 配 PC13 为通用推挽输出、2MHz：CRH 的 bit20..23 对应 PC13
     *    CNF13=00(通用推挽输出) MODE13=10(输出 2MHz) → 写 0x2 */
    GPIOC_CRH &= ~(0xFu << 20);
    GPIOC_CRH |=  (0x2u << 20);

    /* 3. 主循环：亮→延→灭→延。main 永远不返回，返回了 Reset_Handler 里的
     *    死循环会兜住（见 startup.c）。 */
    for (;;) {
        LED_ON();
        delay(400000u);
        LED_OFF();
        delay(400000u);
    }
}
