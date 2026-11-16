# ch04 · 多线程 —— 章节导航

> 书第 4 章 · 对应实验：[`03-zephyr/labs/01-hello`](../labs/01-hello/README.md)（⬜ 骨架已建）
> 章导航：本篇

## 本章讲什么

**Zephyr 的线程模型：k_thread 是什么、两种创建方式、
最有特色的一点——优先级分"协作式（负数）"和"抢占式（非负）"两个世界。**
与 [02-freertos ch03](../../02-freertos/03-task-management/README.md)
对照着读：机制同源，词汇和默认值差异很大。

## 只看这一页（速览）

**主线一句话**：本章解决"线程在 Zephyr 里怎么活"——先看三件家当（TCB + 栈 + 入口），再看两种创建法（动态手续 vs 编译期编制），接着攻全内核最反直觉的优先级两个世界，最后收睡眠让出、两个天生系统线程、以及生死与栈溢出善后。

| 小节 | 一句话结论 |
|---|---|
| 4.1 | 线程 = 控制块 + 栈 + 三参数入口；Zephyr 线程函数**可以返回**（合法终止），主推静态栈 |
| 4.2 | K_THREAD_DEFINE 编译期全定（主推审美）；k_thread_create 的"动态"只是运行中初始化，内存仍是静态的 |
| 4.3 | 数字小 = 高；负数 = 协作式不被抢占；**时间片默认关**，同级轮转要显式开 |
| 4.4 | 让出三动词 k_sleep / k_yield / k_busy_wait；周期不漂靠 k_uptime_get + K_TIMEOUT_ABS_MS 锚定 |
| 4.5 | main 是内核建好的最高抢占式线程、返回合法；idle 全系统最低优先级，循环里 WFI 省电 |
| 4.6 | 三种死法：返回/abort/异常；abort 不回收资源只当逃生门；栈大小按"历史最深用量 × 1.5"调 |

本章最容易踩的坑：

- 从 FreeRTOS 过来把优先级方向配反——Zephyr 数字越小越优先（4.3）
- 两个同级线程只跑一个：时间片默认关，要开 `CONFIG_TIMESLICING`（4.3）
- 自己定义字节数组当栈：MPU 栈保护要求 2 的幂对齐，裸数组不取整会翻车，老实走 K_THREAD_STACK_DEFINE（4.1 Q2）
- 协作式线程里 k_busy_wait = 两个世界一起停摆；毫秒级等待一律 k_sleep（4.4 Q2）
- abort 线程后指望资源自动回收：它持有的信号量/互斥量/内存没人替你收（4.6）

## API 速查卡

| API / 命令 / 配置项 | 一句话作用 | 易错点 |
|---|---|---|
| `K_THREAD_STACK_DEFINE(name, size)`（4.1） | 静态定义线程栈 | 别用裸字节数组当栈：MPU 保护要求 2 的幂，宏会自动取整 |
| `k_thread_create(...)`（4.2） | 运行中创建线程 | TCB/栈存储调用者出，"动态"只是运行中办手续，无堆失败路径 |
| `K_THREAD_DEFINE(...)`（4.2） | 编译期静态定义线程（主推） | main 之前就可能开跑；末参是毫秒延迟不是 K_MSEC |
| `K_ESSENTIAL` / `K_FP_REGS`（4.2） | 选项位：关键线程 / 用 FPU | FPU 线程不加 K_FP_REGS，浮点现场不保存 |
| `K_PRIO_COOP(n)` / `K_PRIO_PREEMPT(n)`（4.3） | 优先级便捷宏 | 小 = 高；负数协作、非负抢占，方向与 FreeRTOS 相反 |
| `CONFIG_TIMESLICING`（4.3） | 时间片开关 | **默认关**：同级公平轮转要显式开并给 TIMESLICE_SIZE |
| `k_sleep(K_MSEC(n))`（4.4） | 相对睡眠 | ±1 tick 误差；可被 k_wakeup 提前叫醒 |
| `k_yield()`（4.4） | 主动让出 | 只让同级，没同级等于白让 |
| `k_busy_wait(us)`（4.4） | 占着 CPU 空转 | 仅限微秒级硬件时序；协作式里用 = 全家停摆 |
| `k_uptime_get()` + `K_TIMEOUT_ABS_MS(t)`（4.4） | 绝对时刻锚定，周期不漂 | 传成相对值会睡到"远古时刻" |
| `CONFIG_MAIN_THREAD_PRIORITY`（4.5） | main 线程优先级（默认最高抢占式） | 配负数 main 变协作式，初始化原子完成 |
| `k_thread_join(tid, K_FOREVER)`（4.6） | 阻塞等线程结束 | 不能 join 自己；死线程可 join（立即返回） |
| `k_thread_abort(tid)`（4.6） | 强制终止 | 不回收它持有的资源，只当逃生门 |
| `k_thread_stack_space_get(tid, &unused)`（4.6） | 读栈水位 | 需开 CONFIG_THREAD_STACK_INFO；水位 ×1.5 调栈大小 |

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 4.1 | 线程是什么：k_thread、TCB 与栈 | [4.1-线程是什么](4.1-线程是什么.md) |
| 4.2 | 创建线程两法：k_thread_create vs K_THREAD_DEFINE | [4.2-创建线程两法](4.2-创建线程两法.md) |
| 4.3 | 优先级两个世界：协作式负数 vs 抢占式非负 | [4.3-优先级两个世界](4.3-优先级两个世界.md) |
| 4.4 | 调度与睡眠：k_sleep / k_yield / k_wakeup | [4.4-调度与睡眠](4.4-调度与睡眠.md) |
| 4.5 | 系统线程：main 线程与 idle 线程 | [4.5-系统线程](4.5-系统线程.md) |
| 4.6 | 生命周期：join / abort 与栈溢出检测 | [4.6-生命周期与栈检测](4.6-生命周期与栈检测.md) |

## 读完本章你应该能回答

- `K_THREAD_DEFINE` 和 `k_thread_create` 的本质区别？（静态 vs 动态分配）
- 为什么协作式线程（负优先级）永远不会被抢占？它和 FreeRTOS 的什么概念对应？
- `k_sleep(K_MSEC(100))` 和 FreeRTOS 的 vTaskDelay 语义一样吗？
- main() 在 Zephyr 里跑在什么上下文？优先级多少？
- Zephyr 里"周期任务不漂移"靠什么？（对照 FreeRTOS 的 vTaskDelayUntil）

## 前置 / 后续

- **前置**：[02-freertos ch03 任务管理](../../02-freertos/03-task-management/README.md)
  （机制同源，先学 FreeRTOS 版再换词）
- **后续**：[ch05 队列/管道/邮箱/workqueue](../05-ipc-workqueues/README.md)
  → 实验 [`03-zephyr/labs/01-hello`](../labs/01-hello/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测输出 | 实验 01 未做（west 环境未建）；数据待落地后补 |
| 书 API 与新版有差 | 已按官方文档校正（如 k_usleep、k_busy_wait 现行行为） |
| SMP 只提了一句 | 书有专门节；F103 单核用不上，需要时补 |
