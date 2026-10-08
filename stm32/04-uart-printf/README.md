# 04-uart-printf —— 串口输出与 printf retarget

> 状态：⬜ 未开始（骨架）。轨道一（裸机 C）第 4 个实验。
> 对应笔记：[第 9 章 STM 上的串口输出](../../book-notes/09-uart-serial/README.md)（9.1–9.5 全章）
> + [补充 ch21 时钟树](../../book-notes/21-clock-tree/README.md)（波特率从哪个时钟来）
> 前置：[03-gpio-blink](../03-gpio-blink/README.md)（✅ 真机实测）

## 目标

- 裸写 USART 寄存器实现 `putc/getc`，再 retarget `printf`（或先做 mini_printf）
- 收发双向：发送字符串 + 中断收字符回显（中断部分也可以留给 05，这里先轮询收）

## 板上事实（写代码前读）

- NUCLEO-F103RB：**USART2 = PA2(TX) / PA3(RX)**，接板载 ST-Link 的虚拟串口（VCP），
  连 USB 就能在主机看到——不需要外接 USB 转串口
- 书（F030R8）用的是 USART1；**别照抄书里的寄存器地址**，差异见
  [09 章导航「与书的差异」](../../book-notes/09-uart-serial/README.md)
- 波特率：默认 HSI 8 MHz，`BRR = 8MHz / 115200 ≈ 69.44` 有 0.64% 误差（9.2 有实测账），
  想准就配 PLL（ch21，可先不做）

## 步骤

1. 开时钟：GPIOA + USART2 + AFIO（F1 的 USART2 默认映射就在 PA2/PA3，不用重映射）
2. PA2 配复用推挽输出、PA3 配浮空/上拉输入（F1 是 CRL 4 位配置，见 03 的寄存器账）
3. `BRR` 按 8 MHz / 115200 算，`CR1` 开 UE/TE/RE
4. 轮询版 `putc`：等 `TXE` → 写 `DR`；`puts` 循环调它
5. retarget：clang/picolibc 下实现 `_write`（或先写 mini_printf，9.5 有讨论）
6. 主机侧：`screen` / `minicom` / `tio` 115200 8N1 看输出

## 验收

- 上电后主机串口看到一行带计数的输出，每秒一行
- 发什么回什么（轮询回显）
- 实测输出（`cat` 串口截图/文本 + `BRR` 寄存器 `mdw` 读回）贴进本 README

## 坑点（待记）

- `BRR` 的小数部分编码（DIV_Mantissa/DIV_Fraction 不是一个纯整数除法）
- 忘了开 USART 时钟 → 写寄存器全无效（03 的 portprobe 已演示过同类坑）
- `\n` vs `\r\n`：终端看不到换行先查这个
