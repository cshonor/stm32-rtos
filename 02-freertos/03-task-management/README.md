# ch03 · 任务管理 —— 章节导航

> 书第 3 章 · 对应实验：[`02-freertos/labs/01-hello-task`](../labs/01-hello-task/README.md)（⬜ 未做）
> 章导航：本篇

## 本章讲什么

**FreeRTOS 的"任务"是全书的地基：任务函数长什么样、四个状态怎么转、
优先级怎么决定谁跑、`vTaskDelay` 和忙等的本质区别、空闲任务在偷偷干什么。**
本章是全 12 章里篇幅最大的一章，也是实验 01-hello-task 的全部理论。

硬件落点（SysTick + PendSV + MSP/PSP 双栈）已在
[01-stm32 ch20.1](../../01-stm32/20-towards-freertos/20.1-任务与调度的硬件落点.md)
讲过；本章站在 **API 与状态机**层面，两者互补。

## 只看这一页（速览）

**主线一句话**：任务是全书地基——3.1 立任务函数三铁律与创建五参数，3.2 用四态
状态机当全章地图，3.3 讲调度器按优先级抢占/同级轮转选人，3.4 分清相对与绝对
两种延时，3.5 揭示空闲任务的收尸职责，3.6 收尾句柄三件套与删除的回收路径。

| 小节 | 一句话结论 |
|---|---|
| 3.1 任务函数与创建 | 三铁律：固定原型、永不返回、退出走 `vTaskDelete`；栈深单位是字，优先级数字大 = 高 |
| 3.2 任务状态机 | 调度器只从 Ready 挑人；Blocked 等事件可带超时，Suspended 只能被别人 resume |
| 3.3 优先级与调度 | 高优先级就绪立刻抢、同级每 tick 轮转；RTOS 不保证公平，高优先级不阻塞低优先级就饿死 |
| 3.4 两种延时 | `vTaskDelay` 相对延时会漂，周期任务用 `vTaskDelayUntil` 锁节拍；毫秒一律 `pdMS_TO_TICKS` |
| 3.5 空闲任务与钩子 | 空闲任务永远在场兼当收尸人；应用任务永不阻塞 = 收尸停摆 = heap 失血 |
| 3.6 句柄删除与动态优先级 | 句柄是管理钥匙（NULL = 自己）；删除只回收 TCB+栈，任务自己申请的资源自己还 |

**本章最容易踩的坑**

- 栈深按字节习惯写 512 实际得 2K 栈——单位是字，20K RAM 经不起几次手滑（3.1）
- 任务优先级与中断优先级数字方向相反，记反了出现"高优先级怎么不抢"的灵异现象（3.1/3.3）
- 不检查阻塞 API 返回值，把"超时"当"收到"处理——队列编程头号 bug 来源（3.2）
- 比较 tick 写 `now >= last + period`，回绕时直接翻车；要用减法写法（3.4）
- 任务删了之后旧句柄没清 NULL，再用就是悬垂指针（3.6）

## API 速查卡

| API / 命令 | 一句话作用 | 易错点 |
|---|---|---|
| `xTaskCreate( f, name, stack, param, prio, &h )` | 创建任务，立即可被调度 | 栈深单位是**字**；返回值要查 `pdPASS` |
| `vTaskStartScheduler()` | 建空闲任务、配 SysTick、启动第一个任务 | 返回即异常（只有 heap 不够建空闲任务才返回） |
| `vTaskSuspend( h )` / `vTaskResume( h )` | 挂起 / 恢复（进出 Suspended） | 挂起 Blocked 任务不会因事件醒；无超时概念 |
| `configUSE_PREEMPTION` | 抢占式调度开关 | 关 0 变协作式，工程上没人关 |
| `taskYIELD()` | 任务主动让出 CPU | 只对同/低优先级有效，高优先级让不出去 |
| `vTaskDelay( ticks )` | 相对延时：从现在睡 N tick | 周期会漂；有 ±1 tick 量化误差 |
| `vTaskDelayUntil( &last, period )` | 绝对节拍：睡到上次唤醒点 + period | `last` 必须先初始化成 `xTaskGetTickCount()` |
| `pdMS_TO_TICKS( ms )` | 毫秒→tick 换算宏 | 别省它写死 tick 数，否则与 tick 配置耦合 |
| `xTaskGetTickCount()` | 读当前 tick 计数 | 比较用减法写法防回绕 |
| `vApplicationIdleHook()` | 空闲钩子，每轮空闲循环调一次 | 永不阻塞、快进快出；需 `configUSE_IDLE_HOOK=1` |
| `vTaskDelete( h )` | 删除任务（NULL = 删自己） | 内存由空闲任务收尸；任务自己申请的资源自己还 |
| `uxTaskPriorityGet( h )` / `vTaskPrioritySet( h, n )` | 读 / 改优先级 | 数字大 = 高；调高者比当前高会立刻抢占 |

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 3.1 | 任务函数的三条铁律与 xTaskCreate 五参数 | [3.1-任务函数与创建](3.1-任务函数与创建.md) |
| 3.2 | 四态状态机：Running / Ready / Blocked / Suspended | [3.2-任务状态机](3.2-任务状态机.md) |
| 3.3 | 优先级与调度：抢占、时间片、优先级数字是反的 | [3.3-优先级与调度](3.3-优先级与调度.md) |
| 3.4 | vTaskDelay 与 vTaskDelayUntil：阻塞不是等待 | [3.4-两种延时](3.4-两种延时.md) |
| 3.5 | 空闲任务与钩子函数：系统在"没事干"时干什么 | [3.5-空闲任务与钩子](3.5-空闲任务与钩子.md) |
| 3.6 | 任务句柄、删除与动态改优先级 | [3.6-句柄删除与动态优先级](3.6-句柄删除与动态优先级.md) |

## 读完本章你应该能回答

- 任务函数为什么"永不返回"？返回了会发生什么？
- Blocked 和 Suspended 都能"不跑"，区别是什么？各自怎么醒来？
- `vTaskDelay(100)` 延时一定精确 100 ms 吗？周期任务该用哪个 API？
- 为什么空闲任务必须存在？把它的优先级调低/删掉会怎样？
- `xTaskCreate` 的五参数里，栈深的单位是什么（不是字节）？
- 删除别的任务和删除自己，资源回收路径差在哪？

## 前置 / 后续

- **前置**：[ch20.1 任务与调度的硬件落点](../../01-stm32/20-towards-freertos/20.1-任务与调度的硬件落点.md)
  （PendSV/SysTick/双栈）+ [ch02 堆内存](../02-heap-memory/README.md)（TCB 和栈从哪来）
- **后续**：[ch04 队列管理](../04-queue-management/README.md)（任务之间怎么传数据）
  → 实验 [`02-freertos/labs/01-hello-task`](../labs/01-hello-task/README.md)

## 本章技术债（诚实记录）

| 债 | 为什么现在不还 |
|---|---|
| 无实测数据（任务创建耗时、栈水位 `uxTaskGetStackHighWaterMark`） | 实验 01 未做，落地后补 |
| 没讲 TCB 内部结构体逐字段 | 机制讲清即可；源码级精读等调试卡住时按需补 |
| 时间片调度（同优先级轮转）只讲了一节 | configUSE_TIME_SLICING 的行为差异待实验演示 |
