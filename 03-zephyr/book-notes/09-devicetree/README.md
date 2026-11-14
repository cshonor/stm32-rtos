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

## 只看这一页（速览）

**主线一句话**：这章解决"换板不改应用"——硬件描述全部声明进 devicetree，从语法与三层叠加（9.1）到 dts 变成 C 宏与设备模型（9.2），再动手写 overlay（9.3）、解剖 SPI/I2C 真驱动的匹配链（9.4），最后和 Linux 及手写寄存器对照收尾（9.5），五篇是"读得懂 → 用得上 → 写得出 → 接得上 → 想得透"的递进线。

| 小节 | 一句话结论 |
|---|---|
| 9.1 dts 语法与三层叠加 | 硬件描述声明化：dtsi → 板级 dts → app.overlay 三层叠加、后写的赢，disabled 节点在构建产物里什么都不留 |
| 9.2 DT 宏族与设备模型 | DT_ 宏族三层读法（定位节点 → 读属性 → 复合属性打包）全是编译期文本拼接、零运行时开销；okay + 驱动匹配即编译期生成 struct device |
| 9.3 overlay 实战 | overlay 两种姿势：`/` 下追加新节点、`&label` 覆盖旧属性；验证纪律是"不猜，看 build/ 产物" |
| 9.4 SPI/I2C 节点解剖 | 匹配链 compatible → binding → DT_DRV_COMPAT → Kconfig → 设备生成，缺一环都点不亮；SPI 的 reg 是片选索引、I2C 的 reg 是从机地址 |
| 9.5 与 Linux 及手写对照 | Linux 把设备树当运行时数据库、Zephyr 当代码生成器输入；dts 没发明新东西，只是把"基址+偏移"声明化、集中化、编译期校验化 |

**本章最容易踩的坑**：

- okay 了 spi1 却忘开 CONFIG_SPI=y——驱动照样不进固件，dts/Kconfig 两个都要对（9.1）
- 用 `&gpiob` 的引脚却忘了 okay gpiob 控制器本身：构建不报错，运行时 device_is_ready 返回 false（9.3）
- dts okay 了但设备不在：按链排查 pinctrl 引脚组、CONFIG、compatible 拼写、驱动配置四环（9.4）
- 书里的 DT 宏编译不过，先去官方 Devicetree API 页查现行拼写（9.2）
- 手改 devicetree_generated.h——每次构建重新生成会被覆盖，改硬件永远回 dts 源头（9.5）

## API 速查卡

| API / 命令 / 配置项 | 一句话作用 | 易错点 |
|---|---|---|
| `status = "okay" / "disabled"` | 节点开关：okay 进固件，disabled 构建产物里什么都不留 | okay 了还要配套 Kconfig，驱动才真进固件 |
| `aliases` / `chosen` | 给硬件起通用名（led0）/ 指定内核用哪个设备（console） | 换调试口只改 chosen 一行，别去改板级其他节点 |
| `compatible` | 节点的型号字符串，驱动认领节点的钥匙 | 写错一个字母，编译期 binding 检查直接报错 |
| `DT_ALIAS` / `DT_NODELABEL` / `DT_PATH` | 第一层定位节点：别名 > 标签 > 完整路径 | 应用首选别名；nodelabel 是 SoC 实现细节 |
| `DT_PROP` / `DT_REG_ADDR` / `DT_IRQN` | 第二层读属性：属性值 / 基址 / 中断号 | 属性名连字符要换下划线；读不存在属性编译期报错 |
| `DT_PROP_OR` / `DT_NODE_HAS_STATUS` | 属性可缺席时给默认值 / 编译期判节点是否 okay | 节点可能缺席时不包 `#if`，编译直接炸 |
| `GPIO_DT_SPEC_GET` + `gpio_pin_configure_dt` | 第三层打包 {控制器, 引脚, 标志} 并操作 | 取代书上的 `DT_GPIO_LABEL` + `device_get_binding` 老流程 |
| `DEVICE_DT_GET` / `device_is_ready` | 取 okay 节点的 `struct device` / 查驱动 init 成败 | 忘 okay 控制器时构建不报错、运行时 ready 为 false |
| `app.overlay` / `boards/<板名>.overlay` | 应用层 dts 补丁：前者全板生效，后者只对指定板 | 板相关改动优先放 boards/ 下，别污染所有板 |
| `pinctrl-0` / `cs-gpios` | 引脚复用组 / SPI 片选 GPIO 数组（写在控制器上） | SPI 子节点 reg 是 cs-gpios 下标，不是地址 |
| `SPI_DT_SPEC_GET` / `spi_write_dt` | 打包 SPI 设备 spec / 按 spec 收发 | 片选拉放由驱动完成，别再手动写 GPIO |
| `build/zephyr/zephyr.dts` | 三层叠加合并产物，验证 overlay 写对没有 | 排查别看源码猜，先搜这个产物文件 |

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
