# RT-Thread 对照：第三种 RTOS 路线，以及为什么不单开一条轨

> freestanding 路径 · 第 4 站（Zephyr）旁支的选读篇，不是书的某一章，不占 ch 编号。
> 对应实验：无（本仓未搭 RT-Thread 环境）；本篇为先行讲解，全文只讲机制，无实测输出。
> 章导航：[03-zephyr/README](README.md) ｜ 相关：[2.1 词汇对照表](02-rtos-fundamentals/2.1-词汇对照表.md) ｜ [2.2 优先级两个世界](02-rtos-fundamentals/2.2-优先级两个世界.md)
>
> 事实准绳：[RT-Thread 官方文档](https://www.rt-thread.org/document/site/) 与
> [Zephyr 官方文档](https://docs.zephyrproject.org)——本篇不抄书，只做横向对照。

## 这一篇讲什么

仓库里有 FreeRTOS（第 3 站）和 Zephyr（第 4 站），缺 RT-Thread。
这一篇回答两个问题：①它和另外两个到底差在哪；②为什么把它写成旁支对照，
而不是开 `04-rt-thread/` 再配一本书、再走一遍 12 章。

结论先给：**RT-Thread 与 Zephyr 同属"中间件齐全型 RTOS"这一层，
功能高度重叠；差别在工程语言（描述文件 vs C 回调）和生态归属（国内 IoT vs 国际工程化）。**
再从 FreeRTOS 过来的人视角看，三者真正的分水岭只有一条——
**内核之上有没有一整套现成的中间件**。

## 先用人话说一遍（新手铺垫）

前面三站其实在回答同一个问题："裸机之上，什么东西值得交给 RTOS？"

- FreeRTOS 的回答：只交调度和 IPC，其余你自己攒。像一个只卖发动机的厂。
- Zephyr 的回答：连整车都给你，而且车怎么装写在一堆 `.dts`/`Kconfig` 描述文件里。
- RT-Thread 的回答：也连整车都给你，但车怎么装写在 C 代码和 menuconfig 里，
  还附赠一个能当场敲命令的控制台（FinSH）。

所以 RT-Thread 和 Zephyr 是同一道题的两种解法，不是两道不同的题。
把两条都走一遍，前 80% 的机制是重复的；真正涨见识的是那 20% 的**工程语言差异**。

| 术语 | 一句话解释 |
|---|---|
| 中间件齐全型 RTOS | 内核之外还带文件系统、网络栈、设备框架、shell 的完整发行版；FreeRTOS 不算，Zephyr 和 RT-Thread 算 |
| FinSH / MSH | RT-Thread 内置的交互式 shell：运行时敲 `list_thread`、`free` 看内核状态，不需要额外上位机 |
| 设备驱动框架 | `rt_device_*` 统一接口：UART/SPI/I2C 等注册成标准设备对象，上层不碰寄存器 |
| Env / scons | RT-Thread 的配置与构建工具链：`menuconfig` 选组件（同 Linux Kconfig），scons 驱动编译 |
| 位图调度 | 用一个整数的比特位标记"哪级有就绪线程"，查最高优先级是 O(1)，与线程数无关 |
| event（事件集） | RT-Thread 的"多事件或/与触发"同步对象：等多个条件，可设"任一满足"或"全部满足" |
| mailbox（邮箱） | RT-Thread 的固定 4 字节消息对象：传指针刚好，传结构体得自己搬 |

## 三者定位对照

| 维度 | FreeRTOS | RT-Thread | Zephyr |
|---|---|---|---|
| 交付边界 | 内核为主，中间件另算 | 内核 + 中间件 + 设备框架 + shell | 内核 + 中间件 + devicetree/Kconfig |
| 内核最小占用 | 约 1KB RAM 量级（仅内核） | 3KB ROM / 1.2KB RAM（Nano 版 2.5KB/1KB，官方数据） | 取决于配置，无统一"最小值"口径 |
| 配置语言 | `FreeRTOSConfig.h` 宏 | `rtconfig.h` + `menuconfig`（Env） | `prj.conf` + `Kconfig` → `autoconf.h` |
| 硬件描述 | 无（驱动的寄存器地址写在 BSP 里） | 驱动源码 + Kconfig 配置 | devicetree（`.dts`/`.overlay`），编译期生成头文件 |
| 交互调试 | 无内置 shell | FinSH / MSH 内置 | Zephyr shell（`CONFIG_SHELL`） |
| POSIX 接口 | 有限（第三方 POSIX 层） | 支持 POSIX 接口 | 一等公民（书副标题就是 POSIX API） |
| 许可 | MIT（AWS 维护） | Apache 2.0 | Apache 2.0 |
| 生态主场 | 芯片厂商 SDK、事实标准 | 国内 IoT / 国产 MCU | 国际工程化、Linux 背景团队 |

## 内核层逐项对照

调度思路三者一致：优先级抢占 + 同优先级时间片轮转 + 互斥量优先级继承。
差异集中在下面这些"数值和名字"上，也是最容易踩坑的地方。

| 机制 | FreeRTOS | RT-Thread | Zephyr |
|---|---|---|---|
| 优先级方向 | **数值越大越高**（0 最低给 IDLE） | **数值越小越高**（0 最高，最低给 idle） | **数值越小越高**（负数协作、非负抢占，见 [2.2](02-rtos-fundamentals/2.2-优先级两个世界.md)） |
| 优先级级数 | `configMAX_PRIORITIES` 可配，常用 5–32 | 最多 256，Cortex-M 普遍配 32（官方） | 协作 + 抢占两段，各自数量可配 |
| 最高优先级查找 | 就绪列表 + 位图（可配优化） | 位图 O(1)，与就绪线程数无关（官方） | 按优先级队列取队首 |
| 轻量 IPC | **任务通知**（task notification），无对象、开销最小 | 无对应物，用信号量/邮箱替代 | 无对应物，用 `k_event`/`k_poll` 组合 |
| 同步三件套 | 二值/计数信号量、互斥量、事件组 | 信号量、互斥量、**事件集**（支持或/与触发） | `k_sem`、`k_mutex`、`k_event` |
| 通信 | 队列、流/消息缓冲区、队列集 | **邮箱（固定 4 字节）**、消息队列、信号（signal） | `k_msgq`、`k_pipe`、`k_fifo/k_lifo`、zbus |
| 内存堆 | `heap_1`~`heap_5` 五套，`pvPortMalloc` | small memory（默认，首次适配+相邻合并）/ slab / memheap 三套，`rt_malloc` | `sys_heap`/`k_heap`，`k_mem_slab` |
| 内存池 | 无独立设施 | **mempool**（固定块，申请可阻塞），`rt_mp_create` | `k_mem_slab` |
| 设备模型 | 无统一框架，各 BSP 自行其是 | `rt_device_*` 统一驱动框架 | devicetree + driver model |

一个值得记住的巧合：**RT-Thread 和 Zephyr 的优先级方向一致（小=高），
都和 Linux nice 值同向；只有 FreeRTOS 是反的。**
从 FreeRTOS 转到另外任何一个，"最重要的线程配最大数字"的直觉必须先改掉。

## 中间件层：重叠的 80% 与差异的 20%

两者都内置文件系统（FAT/LittleFS）、网络栈（RT-Thread 用 lwIP；Zephyr 自有 TCP/IP）、
BLE、GUI、shell，这部分功能清单几乎一一对应。差异在**怎么把硬件和组件告诉系统**：

| 关注点 | RT-Thread | Zephyr |
|---|---|---|
| 硬件描述放哪 | 驱动源码里，`rt_hw_xxx_init()` 手动注册 | `.dts`/`.overlay` 描述文件，编译期生成 `DT_*` 宏 |
| 组件怎么选 | `menuconfig` 勾选项 → `rtconfig.h` | `prj.conf` 配 `CONFIG_*` → `autoconf.h` |
| 加一个新驱动 | 写一个 C 文件，实现 `rt_device_ops`，编译进去 | 写 dts compatible + 驱动匹配表 + Kconfig 项 |
| 改引脚/换板子 | 改 BSP 的 C 宏或配置头 | 改 overlay，业务逻辑不动 |
| 学习曲线 | 从 C 入手最自然，能直接读注册过程 | 先学 dts 语法和三层叠加（见 [9.1](09-devicetree/9.1-dts语法与三层叠加.md)） |

这就是"同一层两条路"的含义：RT-Thread 把配置留在 C 的世界里，
Zephyr 把它抽成描述文件——**与 Linux 设备树同源**
（对照 [9.5 与 Linux 及手写寄存器对照](09-devicetree/9.5-与Linux及手写寄存器对照.md)）。
对走 LDD- 轨的人，Zephyr 的这套机制是"第二遍复习"；RT-Thread 的 C 式注册反而更陌生。

## 为什么不单开第四条轨

| 理由 | 展开 |
|---|---|
| 机制重复 | RT-Thread 与 Zephyr 同属中间件齐全型，调度/IPC/内存三块对照后 80% 一致，再写一遍 12 章边际收益低 |
| 主线契合度 | Zephyr 的 devicetree/Kconfig/west 与 LDD- 轨的 Linux 机制同源，是本仓库"学两遍=记两遍"设计的核心；RT-Thread 的设备框架是另一套 C 式抽象，不服务这条主线 |
| 成本 | 三本书 307 篇笔记的体量已经成型；再开一轨 = 一本教材 + 12 章 + 4 实验 + 真机实测，而本仓目前只有 F103/F407 两块板，RT-Thread 环境尚未搭建 |

真要深入 RT-Thread，最小成本的入口是拿 F103 跑一遍官方 `rt-thread` 仓库的 BSP
（`qemu-vexpress-a9` 或 `stm32f103-fire-arbitrary`），把 `/` 下的 FinSH
敲熟，再回来对照本篇。做到这一步就能判断"要不要再深入"，而不是先开一条轨再说。

## 坑点速查

| 坑点 | 常识怎么说 | 实际是什么 |
|---|---|---|
| 三个 RTOS 优先级方向相同 | 都是"数字大=优先级高" | 只有 FreeRTOS 是；RT-Thread/Zephyr 都是数值小=高，RT-Thread 的 0 是最高且 idle 占最低级 |
| RT-Thread 有任务通知 | FreeRTOS 有 task notification，别的应该也有 | RT-Thread 无对应物，轻量场景用信号量或 4 字节邮箱；从 FreeRTOS 迁代码时这块要重写 |
| 邮箱能传结构体 | 邮箱听起来像队列，什么都能塞 | 邮箱消息固定 4 字节，传结构体只能传指针；动态数据要自己管生命周期 |
| 三个 RTOS 的 malloc 都能在中断里调 | 动态分配哪都能用 | RT-Thread 官方文档明确：堆分配要互斥，不要在 ISR 里分配/释放，可能导致上下文挂起；固定块池才适合中断路径 |
| RT-Thread 是 GPL，产品要开源 | 早期 FreeRTOS 是 GPL 带例外，容易联想 | RT-Thread 是 Apache 2.0，商业友好；本仓真正有许可证负担的是 libopencm3（LGPL-3.0/GPL-3.0，静态链接带义务，见顶层 README 纪律节） |

## 要点回顾

1. RT-Thread 与 Zephyr 同属"内核 + 中间件 + 设备框架"这一层，FreeRTOS 是纯内核层——这是三者真正的分水岭。
2. 优先级方向：RT-Thread/Zephyr 数值小=高（与 Linux nice 同向），FreeRTOS 反着来。
3. RT-Thread 特色：FinSH shell、事件集或/与触发、固定 4 字节邮箱、small/slab/memheap 三套堆 + mempool。
4. 工程语言差异：RT-Thread 留在 C（`rt_device_*` + menuconfig），Zephyr 抽成描述文件（devicetree/Kconfig），后者与 LDD- 轨同源。
5. 不单开轨的结论建立在"机制重复 80% + 主线契合度低 + 建轨成本高"三条上，不是否定 RT-Thread 的价值。

<details>
<summary>Q1：RT-Thread 既然和 Zephyr 同层，那面试被问到怎么答？</summary>

按"分层 + 工程语言"两句话答：

- 分层：FreeRTOS 是内核，RT-Thread 和 Zephyr 是带完整中间件的平台型 RTOS；
- 工程语言：Zephyr 用 devicetree/Kconfig 描述硬件与配置，Linux 背景团队迁移成本低；
  RT-Thread 用 C 式设备框架 + menuconfig，国内生态和中文资料更全，FinSH 调试顺手。

再补一句许可证：RT-Thread Apache 2.0，FreeRTOS MIT，都商业友好；
真正要单独评估的是 libopencm3 静态链接的 LGPL 义务。
与顶层 README「面试备战」节的 MCU 岗问法一致。

</details>

<details>
<summary>Q2：如果只想从 FreeRTOS 平滑过渡，先改哪些直觉？</summary>

三件事：

1. 优先级数字方向反过来——"最重要=最大数"改成"最重要=最小数"，idle 占最低级；
2. task notification 没了——那些"一个任务一个轻量信号"的地方改用信号量或邮箱；
3. 内存分配别在 ISR 里调——要确定性就用 mempool 固定块，而不是 `rt_malloc`。

剩下的队列/信号量/互斥量/优先级继承都是同一套语义，换个函数名就能对上（参考 [2.1](02-rtos-fundamentals/2.1-词汇对照表.md)）。

</details>

## 衔接

本篇是第 4 站的旁支，不进章节序列。回到主线：
- 词汇映射 → [2.1 词汇对照表](02-rtos-fundamentals/2.1-词汇对照表.md)
- 优先级方向 → [2.2 优先级两个世界](02-rtos-fundamentals/2.2-优先级两个世界.md)
- Zephyr 工程语言 → [09-devicetree](09-devicetree/README.md)、[3.3 Kconfig 怎么工作](03-dev-environment-build/3.3-Kconfig怎么工作.md)
- 全路径主线 → [顶层 README](../README.md#这是一条-freestanding-学习路径)

## 代码自测

_注：本仓未搭 RT-Thread 环境，以下代码按 RT-Thread 官方 API 语义编写，未实跑。_

```c
#include <rtthread.h>

/* 动态创建一个线程：rt_thread_create(name, entry, param, stack, priority, tick) */
static void led_thread(void *param)
{
    while (1)
    {
        rt_kprintf("tick=%d\n", rt_tick_get());   /* RT-Thread 自带打印，对应 printf */
        rt_thread_mdelay(500);                    /* 让出 CPU，低优先级线程才有机会跑 */
    }
}

int rtt_demo(void)
{
    /* 优先级 20：数值小=高；0 保留给系统，idle 占最低级 */
    rt_thread_t tid = rt_thread_create("led", led_thread, RT_NULL, 512, 20, 10);
    if (tid != RT_NULL)
        rt_thread_startup(tid);

    /* 固定 4 字节邮箱：适合传指针，不适合直接塞结构体 */
    rt_mailbox_t mb = rt_mb_create("mb", 8, RT_IPC_FLAG_FIFO);
    int payload = 42;
    rt_mb_send(mb, (rt_ubase_t)(intptr_t)&payload);   /* 传地址，生命周期自己管 */
    return 0;
}
MSH_CMD_EXPORT(rtt_demo, start rt-thread contrast demo);
```

**预期现象（若在 RT-Thread BSP 上跑）**：
- FinSH 里敲 `rtt_demo` 启动线程，每 500ms 打印一次 tick；
- 敲 `list_thread` 能看到 `led` 线程状态、优先级 20、剩余时间片；
- 敲 `free` 查看当前堆用量——这是 FreeRTOS 没有的内置可观测性。

**验证路径**：官方 `rt-thread` 仓库 `bsp/stm32/stm32f103-fire-arbitrary` 或
`qemu-vexpress-a9`，按 BSP README 装 Env 工具 → `menuconfig` → `scons`；
本仓 tools/ 工具台只服务 clang/GNU + libopencm3 那条裸机链，不覆盖 RT-Thread。

**常见翻车点**：
- `rt_thread_create` 第 5 个参数是优先级，误按 FreeRTOS 习惯填大数 → 线程排在 idle 前后，几乎不跑；
- 邮箱只收 4 字节，直接 `rt_mb_send(mb, *(uint32_t*)&big_struct)` 会丢数据，必须传指针；
- 线程入口里忘记 `rt_thread_mdelay`/阻塞 → 同优先级线程饿死，比 FreeRTOS 更明显。
