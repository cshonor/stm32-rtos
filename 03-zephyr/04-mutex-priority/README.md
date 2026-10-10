# 04-mutex-priority：k_mutex + 优先级反转

> 状态：⬜ 未开始（骨架）。对照：[02-freertos/04-mutex-priority](../../02-freertos/04-mutex-priority/README.md)
> （互斥量与优先级反转）

- 目标：构造优先级反转场景，k_mutex_lock 触发优先级继承，
  用 CONFIG_*（Kconfig）对比开关前后的调度行为
- API：k_mutex_lock / k_mutex_unlock（对照 xSemaphoreCreateMutex）
- 验收：同一份三任务时间线测试，Zephyr 的优先级继承是否默认开、
  与 FreeRTOS 版反转窗口大小对账
- 待实测输出
- 坑点：待记（Kconfig 里调度相关的 `CONFIG_PRIORITY_CEILING` 等开关在 kernel/Kconfig）
