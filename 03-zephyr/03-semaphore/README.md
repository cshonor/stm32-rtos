# 03-semaphore：k_sem 按键去抖

> 状态：⬜ 未开始（骨架）。对照：[02-freertos/03-semaphore](../../02-freertos/03-semaphore/README.md)
> （二值信号量做按键去抖）

- 目标：EXTI 中断 k_sem_give，任务 k_sem_take 后处理，观察去抖效果
- API：k_sem_take / k_sem_give（对照 xSemaphoreCreateBinary / take·give）
- 验收：同一份「中断次数 vs 有效按键次数」抖动统计，与 02-freertos/03 对账
- 待实测输出
- 坑点：待记（按键在 devicetree 里的 `sw0`/`button0` 别名，gpio_keys 绑定写法）
