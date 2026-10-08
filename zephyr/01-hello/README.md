# 01-hello：hello world + shell

> 状态：⬜ 未开始（骨架）。前置：stm32/ + freertos/ 全通（见 [zephyr/README](../README.md)）

对照：freertos/01-hello-task（先熟悉 west 工作流，再谈任务）

- 目标：`west build -b nucleo_f103rb zephyr/samples/hello_world` 跑通，
  板上（或 QEMU `qemu_cortex_m3`）看到 hello 输出
- 步骤：west init/update → build → flash → 改一行代码重烧
- 验收：板上串口输出 + `.bin` 大小 vs freertos/01 对照（64K Flash 约束的第一笔账）
- 待实测输出
- 坑点：待记
