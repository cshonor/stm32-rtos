# ch09 · DeviceTree（含 SPI / I2C） —— 章节导航

> 书第 9 章 · 对应实验：贯穿（每个实验的 app.overlay）
> 章导航：本篇

## 本章讲什么

**DeviceTree 是 Zephyr"换板不改应用"的底座：硬件长什么样全写在 .dts 里，
驱动按 compatible 匹配，应用只引用节点标签。**
对走过 `LDD-/09` 的读者这是老乡见老乡——同一套语法、同一套理念，
Zephyr 版多了 `DT_` 宏族和 `DEVICE_DT_GET` 设备模型。

本章是 Zephyr 三件套（west/Kconfig/devicetree）里**最深的一件**，
书把它和 SPI/I2C 驱动实例放一章讲——因为看懂驱动实例的前提是看得懂 dts 节点。

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 9.1 | dts 语法与三层叠加：aliases / chosen / status="okay" | [9.1-dts语法与三层叠加](9.1-dts语法与三层叠加.md) |
| 9.2 | 从 dts 到 C：DT_ 宏族、DEVICE_DT_GET、struct device | [9.2-DT宏族与设备模型](9.2-DT宏族与设备模型.md) |
| 9.3 | app.overlay 实战：给 nucleo_f103rb 加一个 LED/按钮节点 | [9.3-overlay实战](9.3-overlay实战.md) |
| 9.4 | SPI/I2C 驱动实例解剖：compatible 匹配链与 cs-gpios | [9.4-SPI-I2C节点解剖](9.4-SPI-I2C节点解剖.md) |
| 9.5 | 与 Linux 设备树及手写寄存器的对照 | [9.5-与Linux及手写寄存器对照](9.5-与Linux及手写寄存器对照.md) |

## 读完本章你应该能回答

- `status = "disabled"` 的节点在构建产物里留下什么？（什么都不留——为什么？）
- `GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios)` 这行宏展开后经过了哪几步？
- 板级 dts、SoC 级 dtsi、应用 overlay 三者的叠加顺序？
- Zephyr 的设备驱动模型和 Linux 的 platform_driver 怎么对应？

## 前置 / 后续

- **前置**：`LDD-/09`（Linux 设备树）+ [ch03 构建原理](../03-dev-environment-build/README.md)
- **后续**：所有后续实验的 overlay 都用到；[ch06 文件系统](../06-filesystems/README.md) 的分区表也是 devicetree

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测输出 | 01-hello 实验未做（west 环境未建）；overlay 示例照官方写法给出，待实验落地后补真实 dts 片段与构建产物截图 |
| 书 API 与新版有差 | 已按官方文档校正（GPIO_DT_SPEC_GET 取代 device_get_binding 路线、pinctrl 取代散装 pinmux），见 9.2/9.4 对照表 |
| LDD-/09 对照未展开 | 本仓无 LDD- 目录；9.5 只做了语义层对照，逐文件对照待 LDD- 侧笔记落地后补 |
