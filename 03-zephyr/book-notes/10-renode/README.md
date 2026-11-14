# ch10 · Renode 仿真 —— 章节导航

> 书第 10 章 · 对应实验：无板替代路径（与 `qemu_cortex_m3` 互补）
> 章导航：本篇

## 本章讲什么

**Renode 是 Antmicro 的全系统仿真框架：不写一行真板代码，
用 .repl 文件描述一块板（MCU + 外设 + 连线），直接把 zephyr.elf 跑进去。**
Zephyr 官方对 Renode 有一等支持（`west build -t run`）。
价值场景：CI 自动化测试、没板子时先跑通前两个实验、复现"只在特定时序出现"的 bug。

## 只看这一页（速览）

**主线一句话**：这章解决"没板子怎么跑/验固件"——先分清 QEMU（仿一颗核）与 Renode（仿一整块板）的定位（10.1），再用 .repl 把 nucleo_f103rb 用文本"画"出来跑起 elf（10.2），最后用 Monitor 命令与 Robot Framework 把翻查和验收自动化（10.3），三篇是"选对工具 → 搭好台子 → 自动判卷"的递进线。

| 小节 | 一句话结论 |
|---|---|
| 10.1 Renode 与 QEMU 定位差异 | QEMU 仿指令集+极简外设、验纯软件逻辑；Renode 用 .repl 仿整板、验软硬件接口；时序类问题只有真板能最终裁定 |
| 10.2 .repl 平台描述 | .repl 是 Renode 版 dts：类型@基址 + 中断连线，数据与手册/dts/手写宏同源；最小平台只需 cpu/nvic/flash/sram/uart，外设用到才加 |
| 10.3 交互与自动化 | Monitor 管人在回路的翻查（GetPinState/pause/LogPeripheralAccess），Robot Framework 管无人值守的断言回归；errata 与时序永远在真板侧 |

**本章最容易踩的坑**：

- 时序类 bug 在仿真里可能永不出现——仿真时钟与真板时钟无对应关系（10.1）
- 把"仿真通过"当"真板通过"：仿真失败也可能是模型错而非你的错（10.1）
- 从零写 .repl 而不去抄 platforms/cpus/ 现成平台文件——慢一个数量级（10.2）
- 访问未建模地址只告警不崩，忘了"外设用到才加"会误以为缺模型是错误（10.2）
- 把 Robot 的 timeout=5 当真实秒数——那是虚拟时间，度量不了真板时序（10.3）
- 真芯片的 errata 不在外设模型里，模型按 datasheet 标准行为实现（10.3）

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 10.1 | Renode 与 QEMU 的定位差异：全系统仿真 vs 指令集仿真 | [10.1-Renode与QEMU定位差异](10.1-Renode与QEMU定位差异.md) |
| 10.2 | .repl 平台描述：把 nucleo_f103rb 用文本"画"出来 | [10.2-repl平台描述](10.2-repl平台描述.md) |
| 10.3 | 交互与自动化：Monitor 命令、Robot Framework 测试 | [10.3-交互与自动化](10.3-交互与自动化.md) |

## 读完本章你应该能回答

- Renode 和 Zephyr 自带的 qemu_cortex_m3 各自适合验什么？
- 仿真里的"时间"和真板时间有什么关系？外设时序能信多少？
- 为什么 CI 里跑 RTOS 测试几乎必选 Renode？

## 前置 / 后续

- **前置**：[ch03 构建原理](../03-dev-environment-build/README.md)
- **后续**：无板期的替代实验路径；与 03-zephyr/README 的 qemu_cortex_m3 路线对比后选型

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测输出 | 本仓已有真板（F103 在手），仿真路径优先级低；.repl/.resc/.robot 示例照官方语法给出，未在本机跑过 |
| F103 平台文件未核对 | Renode 社区对 STM32F1 的外设模型覆盖度未逐一确认；真要用时先查 platforms/cpus/ 现成文件 |
