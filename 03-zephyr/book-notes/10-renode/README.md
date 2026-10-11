# ch10 · Renode 仿真 —— 章节导航

> 书第 10 章 · 对应实验：无板替代路径（与 `qemu_cortex_m3` 互补）
> 章导航：本篇

## 本章讲什么

**Renode 是 Antmicro 的全系统仿真框架：不写一行真板代码，
用 .repl 文件描述一块板（MCU + 外设 + 连线），直接把 zephyr.elf 跑进去。**
Zephyr 官方对 Renode 有一等支持（`west build -t run`）。
价值场景：CI 自动化测试、没板子时先跑通前两个实验、复现"只在特定时序出现"的 bug。

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
