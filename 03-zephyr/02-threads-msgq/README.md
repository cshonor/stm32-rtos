# 02-threads-msgq：双线程 + k_msgq

> 状态：⬜ 未开始（骨架）。对照：[02-freertos/02-queue](../../02-freertos/02-queue/README.md)
> （中断 → 队列 → 任务，下半部思想的 Zephyr 版）

- 目标：两个 k_thread + k_msgq 传递消息，中断侧 put、任务侧 get
- API：k_msgq_put / k_msgq_get（对照 xQueueSend / xQueueReceive）
- 验收：与 02-freertos/02 同一份「连发 64+ 字节不丢」测试，两版代码行数 / `.text` 对账
- 待实测输出
- 坑点：待记（devicetree 里 UART 节点怎么开、中断谁注册——框架包掉的部分要写出来）
