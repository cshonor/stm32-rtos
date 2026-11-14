# ch05 · 消息队列 / 管道 / 邮箱 / workqueue —— 章节导航

> 书第 5 章 · 对应实验：[`03-zephyr/02-threads-msgq`](../../02-threads-msgq/README.md)（⬜ 骨架已建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的线程间通信工具箱比 FreeRTOS 丰富得多：k_msgq（≈FreeRTOS 队列）、
k_pipe（字节流）、k_mbox（带优先级的邮箱）、k_fifo/k_lifo（链表传递）、
以及 Linux 风格的 workqueue（延迟工作项）。**本章的核心问题是
"什么场景选哪个"——工具多，选错比不会用更常见。

对照 [02-freertos/book-notes ch04](../../../02-freertos/book-notes/04-queue-management/README.md)：
FreeRTOS 一个 queue 打天下；Zephyr 按语义细分出五六种对象。

## 只看这一页（速览）

**主线一句话**：本章解决"线程之间怎么对话"——按数据形态选对象（齐整消息 msgq、字节流 pipe、传指针 fifo/lifo、带优先级 mbox），最后收下"ISR 不能干活、活要交出去"这个最普遍需求的内核级答案 workqueue。

| 小节 | 一句话结论 |
|---|---|
| 5.1 | k_msgq ≈ FreeRTOS queue，但静态定义、统一 k_timeout_t、ISR 里不换 API 只传 K_NO_WAIT |
| 5.2 | 字节流用 k_pipe（可部分读写），传指针用 k_fifo/k_lifo（零拷贝，但所有权自己管） |
| 5.3 | k_mbox 支持优先级/异步/过滤，但官方视为 legacy——新代码先用 k_msgq，确需插队再升级 |
| 5.4 | workqueue 是内核级下半部：ISR 只登记，handler 在线程上下文干活；重活自建 workqueue 隔离 |

本章最容易踩的坑：

- 带着 FreeRTOS 经验找 FromISR 变体——Zephyr 不换 API，ISR 里传 `K_NO_WAIT` 即可（5.1）
- k_fifo 节点第一个成员忘了放 `sys_snode_t`，CONTAINER_OF 反查直接崩（5.2）
- 为"紧急消息插队"提前上 k_mbox：先用多个 k_msgq 分级，k_mbox 是确认需要才升级的选项（5.3）
- 在 system workqueue 的 handler 里干重活/长阻塞，拖住全系统的轻活（5.4）
- 把 k_timer 回调当线程用：它跑在 ISR 上下文不能干活，要干活用 k_work_delayable（5.4 Q2）

## API 速查卡

| API / 命令 / 配置项 | 一句话作用 | 易错点 |
|---|---|---|
| `K_MSGQ_DEFINE(name, size, depth, align)` | 编译期静态定义消息队列 | 第 2 参是**单项大小**不是总字节数；align 影响 RAM padding |
| `k_msgq_put` / `k_msgq_get` | 阻塞收发一条消息 | ISR 里传 `K_NO_WAIT`，别找 FromISR 变体 |
| `k_msgq_peek` / `k_msgq_purge` | 读队首不删 / 清空队列 | peek 无超时参数，空队列直接 `-ENOMSG` |
| `K_PIPE_DEFINE` + `k_pipe_put` / `k_pipe_get` | 字节流管道，支持部分读写 | 返回后看 `written/read_bytes`；`min_xfer` 是"最少传输量"不是上限 |
| `K_FIFO_DEFINE` + `k_fifo_put` / `k_fifo_get` | 传指针（链表节点），零拷贝 | 节点必须 `sys_snode_t` 打头且长寿命；`k_fifo_put` ISR 安全 |
| `CONTAINER_OF` | 由节点指针反查宿主结构体 | 成员名/类型写错编译过、运行时读歪 |
| `K_MEM_SLAB_DEFINE` + `k_mem_slab_alloc/free` | fifo 节点的 O(1) 内存池 | 取走的节点谁用谁还，漏 free 池子耗尽 |
| `k_mbox_put` / `k_mbox_async_put` / `k_mbox_get` | 带优先级/异步/过滤的邮箱 | 官方 legacy；`priority` 是消息排序权重，与线程优先级无关 |
| `K_WORK_DEFINE` + `k_work_submit` | 一次性工作项，ISR 交活标配 | 同一 work 在队里不重复排队，只执行一次 |
| `K_WORK_DELAYABLE_DEFINE` + `k_work_schedule` | 可延迟/周期工作项 | 周期靠 handler 里手动重排，无自动重载 |
| `k_work_cancel_delayable` | 取消未执行的延迟工作项 | 已进队执行的取消不掉 |
| `k_work_queue_start` + `k_work_submit_to_queue` | 自定义 workqueue 隔离重活 | system workqueue 里堵了拖全系统 |

## 小节清单

| 小节 | 标题 | 状态 |
|---|---|---|
| [5.1 k_msgq 与 FreeRTOS 队列对照](5.1-k_msgq与FreeRTOS队列对照.md) | 静态定义、k_timeout_t、ISR 免换 API | ✅ |
| [5.2 k_pipe 与 k_fifo/k_lifo](5.2-k_pipe与k_fifo_k_lifo.md) | 字节流 vs 指针传递、sys_snode_t 侵入式链表 | ✅ |
| [5.3 k_mbox 邮箱](5.3-k_mbox邮箱.md) | 优先级消息、异步发送、legacy 定位 | ✅ |
| [5.4 workqueue](5.4-workqueue.md) | k_work/k_work_delayable、与 Linux workqueue 同源 | ✅ |

## 读完本章你应该能回答

- k_msgq 和 FreeRTOS queue 在"传值/传指针、阻塞语义、ISR 可用性"上的异同？
- workqueue 和 FreeRTOS 的"守护任务+命令队列"（软件定时器那套）是什么关系？
- k_work_delayable 和 FreeRTOS 软件定时器怎么对应？取消语义呢？
- 中断里交活，为什么 Zephyr 惯用 k_work_submit 而 FreeRTOS 惯用 xQueueSendFromISR？

## 前置 / 后续

- **前置**：[ch04 多线程](../04-multithreading/README.md)
  + [02-freertos/book-notes ch04 队列](../../../02-freertos/book-notes/04-queue-management/README.md)
- **后续**：[ch09 DeviceTree](../09-devicetree/README.md)（驱动里到处是 workqueue）

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 小节无实测数据 | 实验 02 未做；届时与 02-freertos/02-queue 做对照实测 |
