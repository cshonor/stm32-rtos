# @TARGET@

> 由 `tools/newlab.sh` 生成 · 板子：**@BOARD_NAME@**（`BOARD=@BOARD@`）

## 这个实验要回答什么

（一句话写清楚：要验证的机制是什么，不是"学习 XX"这种）

## 构建与烧录

```bash
source tools/env.sh --export     # 工具不在 PATH 上时先做这一步
make                             # 编译，看体积账单
make flash                       # 烧进板子（复位后就开始跑）
make BOARD=@BOARD@ probe         # 只读探测：halt 后把向量表/寄存器读回来
```

## 实测输出

（把 `make`、`make flash`、`make probe` 的真实输出贴在这里。
  仓库纪律：每个实验必须真机跑通再写笔记，实测输出贴进 README。）

```
（待填）
```

## 坑点（原书/常识怎么说 / 实际是什么）

| 说法 | 实际 |
|---|---|
|  |  |

## 与 Linux 轨的对照

| 概念 | Linux 轨（LDD-） | 这里（MCU 轨） |
|---|---|---|
|  |  |  |

## 下一步

- 上一篇：
- 下一篇：
