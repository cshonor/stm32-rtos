/* main.c —— stm32/03-gpio-blink
 *
 * 对应书：《裸机C编程》第 3 章
 *   3.3.1 初始化硬件          → 开 GPIOA 的时钟（第一件事永远是开时钟）
 *   3.3.2 GPIO 引脚编程       → 把 PA5 配成通用推挽输出
 *   3.3.3 切换 LED            → 用 BSRR 置位/复位
 *
 * 板子：NUCLEO-F103RB（STM32F103RBT6，Cortex-M3，128K Flash / 20K RAM）
 *   用户 LED LD2 接在 **PA5**（Nucleo-64 板载丝印 LD2，绿色）
 *   用户按键 B1 接在 **PC13**（见 05-exti-button，本实验不碰）
 *
 * 寄存器地址全部来自 RM0008（STM32F10xxx 参考手册）第 9 章，
 * 不是"抄别人的宏"，所以每一行都能对到手册的偏移表上。
 *
 * 调试观测点（本文件里那几个 volatile 变量）：
 *   故意留在内存里，烧完用 openocd 读回来就能证明"代码真的按预期改了硬件"，
 *   不用靠"灯亮不亮"这种主观判断（灯还可能被 SB 跳线断开）。
 *
 * 构建/烧录见 Makefile；实测输出见本目录 README.md 与 book-notes 第 3 章。
 */

#include <stdint.h>

/* ---------------- 寄存器地图（RM0008 §9.2 Memory map） ---------------- */

#define RCC_BASE      0x40021000u
#define GPIOA_BASE    0x40010800u

#define RCC_APB2ENR   (*(volatile uint32_t *)(RCC_BASE   + 0x18u))  /* 0x40021018 */
#define GPIOA_CRL     (*(volatile uint32_t *)(GPIOA_BASE + 0x00u))  /* 0x40010800 */
#define GPIOA_CRH     (*(volatile uint32_t *)(GPIOA_BASE + 0x04u))  /* 0x40010804 */
#define GPIOA_IDR     (*(volatile uint32_t *)(GPIOA_BASE + 0x08u))  /* 0x40010808 */
#define GPIOA_ODR     (*(volatile uint32_t *)(GPIOA_BASE + 0x0Cu))  /* 0x4001080C */
#define GPIOA_BSRR    (*(volatile uint32_t *)(GPIOA_BASE + 0x10u))  /* 0x40010810 */
#define GPIOA_BRR     (*(volatile uint32_t *)(GPIOA_BASE + 0x14u))  /* 0x40010814 */

/* 位号命名成宏，别让 0x20 这种东西散落在代码里 */
#define LED_PIN       5u
#define RCC_IOPAEN    (1u << 2)      /* APB2ENR bit2：GPIOA 时钟使能 */

/* ---------------- 调试观测点 ---------------- */

/* .noinit：放在 RAM 里但启动代码不清零。
 * 为什么必须这样 —— 01-bare-metal 实测过：写在 .bss 里的面包屑
 * 会被 Reset_Handler 第三步的清零循环抹掉，真机上表现为"永远读到 0"。 */
__attribute__((section(".noinit"))) volatile uint32_t boot_stage;
__attribute__((section(".noinit"))) volatile uint32_t apb2enr_readback;

volatile uint32_t crl_after_config;   /* 配完 PA5 之后 CRL 的真实值 */
volatile uint32_t odr_after_set;      /* BSRR 置位后读到的 ODR */
volatile uint32_t odr_after_reset;    /* BSRR 复位后读到的 ODR */
volatile uint32_t blink_count;        /* 共翻转了多少次 */

/* ---------------- 极简延时 ----------------
 * ⚠ 这是"教学用"延时，不是工程用延时：
 *   1. 循环次数和主频强相关（默认 HSI 8MHz），换板子就得改；
 *   2. -O0 和 -Os 下的实际时间不一样（编译器可能把循环整体改掉）；
 *   3. 期间 CPU 全在空转，什么都不干。
 * 工程做法见补充篇 ch19（SysTick 定时器 + 中断）。
 */
static void delay(volatile uint32_t n)
{
    while (n--) {
        __asm__ volatile("nop");
    }
}

int main(void)
{
    boot_stage = 1;

    /* ---------- 3.3.1 初始化硬件 ----------
     * 复位后 RCC_APB2ENR = 0x00000000（实测），所有外设时钟默认关闭。
     * 这一行不写：下面所有 GPIOA_* 的写都会"静默丢失"——不报错、不警告、
     * 寄存器读回还是复位值。裸机上最难查的一类问题。
     */
    RCC_APB2ENR |= RCC_IOPAEN;

    apb2enr_readback = RCC_APB2ENR;   /* 读回来存着，供调试器核对 */
    boot_stage = 2;

    /* ---------- 3.3.2 GPIO 引脚编程 ----------
     * F1 的引脚配置藏在 CRL/CRH 里，每个引脚占 4 位： [CNF1 CNF0 MODE1 MODE0]
     *   输入类（CNF=00/01/10）时 MODE 表示输入模式；
     *   输出类（CNF=00 通用推挽 / 01 通用开漏 / 10 复用推挽 / 11 复用开漏）
     *   时 MODE 表示最高速度：01=10MHz, 10=2MHz, 11=50MHz。
     * PA5 落在 CRL 的 bits[23:20]（5 × 4 = 20）。
     *
     * 「先清后置」不能省：一个 CRL 管 8 个引脚，
     * 若直接 `GPIOA_CRL = 0x00200000`，等于把 PA0–PA4、PA6、PA7
     * 的配置一起写成 0000（模拟输入）—— 那是把别人的配置抹了。
     */
    GPIOA_CRL &= ~(0xFu << (LED_PIN * 4u));      /* 清 PA5 的 4 位 */
    GPIOA_CRL |=  (0x2u << (LED_PIN * 4u));      /* CNF=00, MODE=10 → 2MHz 推挽输出 */

    crl_after_config = GPIOA_CRL;
    boot_stage = 3;

    /* ---------- 3.3.3 切换 LED ---------- */
    for (;;) {
        GPIOA_BSRR = (1u << LED_PIN);            /* 写低 16 位 → 置位 */
        odr_after_set = GPIOA_ODR;               /* 读回：bit5 应为 1 */
        blink_count++;

        delay(400000u);

        GPIOA_BSRR = (1u << (LED_PIN + 16u));    /* 写高 16 位 → 复位 */
        odr_after_reset = GPIOA_ODR;             /* 读回：bit5 应为 0 */
        blink_count++;

        delay(400000u);
    }
}
