# 第 15 章 命令行参数与原始 I/O —— 章节导航

> 书：第 15 章 命令行参数和原始 I/O（原书 p212–218）
> 对应实验：**全部为本次实测**（clang 23.1.0 / macOS arm64 / Apple Silicon）

## 这一章在讲什么

**书这一章是第 14 章的"下一层"：绕过 stdio 缓冲，直接用 `open/read/write/ioctl`。**
对裸机轨来说，这一章的密度比 14 章高得多——因为**裸机上根本没有 stdio**：

1. **程序从哪里拿输入**（`argc/argv`）→ 裸机的**串口命令行**是同一套思路；
2. **`read/write` 必须循环**——裸机上"写不完"是常态（环形缓冲满 = 拒绝）；
3. **`errno` 是 POSIX 的概念**——裸机上要用返回码替代它；
4. **`ioctl` 的形状**（命令号 + 参数）→ 裸机驱动的**命令分发表**。

一句话概括全章：

> **14 章是"有 libc 的世界"，15 章是"只有内核（或只有硬件）的世界"——
> 也就是裸机每天所处的世界。**

## 小节清单

| 小节 | 标题 | 笔记 |
|---|---|---|
| 15.01 | 命令行参数 | [15.01-命令行参数](15.01-命令行参数.md) |
| 15.02 | 原始 I/O | [15.02-原始IO](15.02-原始IO.md) |
| 15.03 | 二进制模式 | [15.03-二进制模式](15.03-二进制模式.md) |
| 15.04 | ioctl | [15.04-ioctl](15.04-ioctl.md) |

> 说明：本章小节**页码未从目录页逐条核对**（只知整章 p212–218），故不列单节页码。
> 小节清单来自旧章笔记头部的编号（**15.01–15.04**）；
> 顶层索引原先写的 `15.01–15.5` 是错的，已订正为 **15.01–15.04**。

## 与书的差异（重要）

| 书 | 我 |
|---|---|
| 15.1 讲 `argc/argv` | **实测 `argc=4` / `argv[0]=./arg` / `argv[argc]==NULL`**；⚠ 重点补了 **`atoi` vs `strtol`**：`atoi("abc")`→0（无法区分"真的是 0"和"解析失败"）、`atoi("99999999999999999999")`→**-1**（UB）、`strtol` 三件套（`end==str` / `*end!='\0'` / `errno==ERANGE`，**必须先清零 errno**）；裸机对应 = 串口命令行 + 函数指针表 |
| 15.2 讲原始 I/O | **把"无缓冲"实测出来**：`write(fd,"abc",3)` 后**立刻查磁盘 = 3**（对比 14 章 `fprintf` 后磁盘 = **0**）；`open` 返回 fd=3、失败 -1 + `errno=2`；`open(...,0600)` 实测权限 **0600**（umask 022）；⚠ **短读实测**：请求 100 字节 → `read` 返回 **6**，再读返回 **0（=EOF，不是错误）**；`write_all` 循环 + `EINTR` 重试 |
| 15.3 讲二进制模式 | ⚠ **`O_BINARY` 在 POSIX 上根本未定义**（实测输出），只有 Windows 有 → 跨平台必须写 `#ifndef O_BINARY #define O_BINARY 0`；⚠ 实测 `\n` **不被翻译**（`61 0a 62 0a`，4 字节进 4 字节出）、`\r` **不被吞**（`78 0d 0a 79`）；⚠ 真正的坑不是模式串而是 **`strlen` 遇到 `0x00` 就停**（8 字节块测出 **1**）；⚠ `fread` 返回**项数不是字节数**（`fread(r,4,3)` → **2**） |
| 15.4 讲 ioctl | ⚠ **同一类失败实测给出三种 errno**：**102 ENOTSOCK** / **19 ENODEV** / **25 ENOTTY** → 结论是**只判 -1 并兜底，别写死 errno**；⚠ `FIONREAD` 对**普通文件（3 字节）和目录（768 字节）居然成功**；命令号位域实测（`TIOCGWINSZ = 0x40087468`，grp='t' nr=**104** size=**8**）；⚠ **macOS 没有 `_IOC_DIR/_IOC_TYPE/_IOC_SIZE`**（Linux 专有），且 `IOC_VOID=0x20000000` 的 bit29 **落在 size 字段里**（`_IO('m',0)` 解出 len=**8192**）；裸机映射 = `uart_ioctl` 命令分发表 |
| 书里没提 | 裸机上没有 `errno` → 用**返回错误码**（`enum { OK=0, ERR_TIMEOUT=-1, ... }`），理由：ISR 里全局变量会被覆盖、返回码在签名里看得见、代码量最小 |

## 核心实测数据（本章的锚点）

```
① argc / argv
./arg a b 3     -> argc=4
   argv[0]=./arg  argv[1]=a  argv[2]=b  argv[3]=3
   argv[argc] = (NULL)            ← 标准保证，可以当哨兵
./arg           -> argc=1（只有 argv[0]）

② ⚠ atoi 无法报告失败（全部实测）
atoi("abc")                    -> 0        ← 和 atoi("0") 无法区分
atoi("  42abc")                -> 42       ← 吃掉前缀空格，尾巴垃圾不管
atoi("99999999999999999999")   -> -1       ← ⚠ 溢出是 UB，这里吐出 -1
strtol("abc")                  -> end==str           （一个字符都没转换）
strtol("42abc")                -> *end=='a'          （尾巴有垃圾）
strtol("99999999999999999999") -> errno==ERANGE      （⚠ 必须先 errno=0）

③ ⚠ 无缓冲的直接证据（写 N 字节后立刻查磁盘大小）
fprintf（stdio，14 章）  -> 0     ← 还在用户态缓冲里
write  （raw，本章）     -> 3     ← 立刻就是 3

④ open / 权限 / errno
open("raw.txt", O_CREAT|O_WRONLY, 0644) -> fd=3
open("不存在的文件", O_RDONLY)          -> -1, errno=2 (No such file or directory)
open(..., 0600)                          -> 实际权限 0600（umask=022：0600 & ~022 = 0600）

⑤ ⚠ 短读（请求 100 字节）
echo "hello" | ./sr
请求读 100 字节 -> read 返回 6   （"hello\n"）
再读一次        -> read 返回 0   （0 = EOF，不是错误）

⑥ 二进制 / 文本模式（POSIX 上逐字节相同）
raw   open()+write("a\nb\n") -> 磁盘 4 字节: 61 0a 62 0a
stdio fopen("w")             -> 磁盘 4 字节: 61 0a 62 0a
源文件 x 0d 0a y，"r" 读出   -> 4 字节: 78 0d 0a 79   ← ⚠ 不吞 \r
O_BINARY 未定义（POSIX 无此标志） / O_TEXT 未定义

⑦ ⚠ 二进制数据里的 0x00（blk = 01 00 ff 41 42 00 7f 80，共 8 字节）
write(fd, blk, 8)  -> 8        ✅ 显式长度
read(fd, r, 8)     -> 8        ✅
fread(r,1,8,f)     -> 8        ✅
strlen(blk)        -> 1        ⚠ 遇到第一个 0x00 就停
printf("%s")       -> []       ⚠ 同上
fread(r,4,2)       -> 2 项
fread(r,4,3)       -> 2 项     ⚠ 短项返回项数，不是字节数

⑧ ⚠ ioctl 的成功与失败（同一台机器的三种 errno）
isatty(0)=0 isatty(1)=0 isatty(2)=0         ← 非终端环境
ioctl(stdout, TIOCGWINSZ) -> -1 errno=102 (Operation not supported on socket)
ioctl(stdin,  FIONREAD)   -> -1 errno=19  (Operation not supported by device)
ioctl(普通文件, TIOCGWINSZ) -> -1 errno=25  (Inappropriate ioctl for device)
echo "hello" | ...  ioctl(stdin, FIONREAD) -> 0  可读=6 字节
ioctl(普通文件, FIONREAD) -> 0  可读=3 字节
ioctl(目录,     FIONREAD) -> 0  可读=768 字节
script -q /dev/null ./io2（pty）：
  isatty=1  TIOCGWINSZ -> 0  行=0 列=0     ← ⚠ 成功但尺寸全 0，照样要兜底

⑨ ioctl 命令号解码（macOS）
sizeof(int)=4  IOC_VOID=0x20000000 IOC_OUT=0x40000000 IOC_IN=0x80000000 IOC_INOUT=0xc0000000
MY_RESET    = 0x20006d00  dir=2 len=8192 grp='m' nr=0   ← ⚠ len 被 IOC_VOID 污染
MY_GET_BAUD = 0x40046d01  dir=4 len=4    grp='m' nr=1
MY_SET_BAUD = 0x80046d02  dir=8 len=4    grp='m' nr=2
MY_XFER     = 0xc0046d03  dir=c len=4    grp='m' nr=3
FIONREAD    = 0x4004667f  dir=4 len=4    grp='f' nr=127
TIOCGWINSZ  = 0x40087468  dir=4 len=8    grp='t' nr=104
_IOR('n',1,int) = 0x40046e01                            ← 只有魔数不同 → 不撞号
```

## 读完本章你应该能回答

- `argv[argc]` 是什么？（实测：**NULL**，标准保证）
- 为什么不能用 `atoi` 解析命令行参数？（**无法区分 0 和解析失败**；溢出是 UB，实测给出 -1）
- 用 `strtol` 检测失败要看哪三件事？（`end==str` / `*end!='\0'` / `errno==ERANGE`）
- 用 `strtol` 前必须先做什么？（**`errno = 0`**）
- "raw I/O 无缓冲"的实测证据是什么？（写 3 字节后磁盘**立刻 = 3**；stdio 是 **0**）
- `open` 失败返回什么？怎么拿到原因？（**-1 + errno**，实测 errno=2）
- `open(..., 0600)` 在 umask 022 下实际权限是多少？（**0600**）
- 请求读 100 字节只返回 6，是错误吗？（**不是**，是短读；返回 **0** 才是 EOF）
- `write_all` 循环里除了 `EINTR` 还要防什么？（**返回 0 时不能死循环**）
- POSIX 上有 `O_BINARY` 吗？（**没有**，实测未定义）
- 为什么跨平台代码还是要写 `"wb"`？（Windows 上不写就会 `\n`→`\r\n`）
- 8 字节二进制块 `01 00 ff ...`，`strlen` 返回几？（**1**）
- `fread(buf,4,3,f)` 在 8 字节文件上返回几？代表几个字节？（**2 项 = 8 字节**）
- `fread` 推荐写法为什么是 `size=1`？（返回值直接是字节数）
- ioctl 失败一定是 `ENOTTY` 吗？（**不一定**，实测 102 / 19 / 25 都出现过）
- 怎么可靠判断 fd 是不是终端？（`isatty(fd)`，比 errno 靠谱）
- ioctl 命令号里的"魔数"有什么用？（实测 `'m'` vs `'n'` 只差一位，防驱动间撞号）
- 裸机上没有 `errno`，怎么办？（**返回错误码 enum**，不用全局变量）
- 裸机上为什么要手动补 `\r`？（UART 是纯字节通道，**没有文本模式替你翻译**）

## 前置 / 后续

- 前置：[第 6 章 数组指针字符串](../06-arrays-pointers-strings/README.md)（`argv` 就是 `char *[]`）、
  [第 8 章 复杂数据类型](../08-complex-types/README.md)（结构体、函数指针表）、
  [第 9 章 串口](../09-uart-serial/README.md)（裸机的字节通道、手动补 `\r`）、
  [第 10 章 中断](../10-interrupts/README.md)（环形缓冲的"拒绝写入" = 裸机版短写）、
  [第 14 章 缓冲文件 I/O](../14-buffered-file-io/README.md)（本章的对照面）
- 后续：[第 16 章 浮点数](../16-floating-point/README.md)
- **LDD- / TLPI 侧**：
  - `open/read/write/close` 就是 **TLPI Ch4（文件 I/O）** 的主角，
    本章只是"STM32 书视角的速写"——真正的展开在 TLPI；
  - **短读/短写**：TLPI Ch5（`readn`/`writen`）、Ch63（`select`/`epoll` 的非阻塞语义），
    与 [15.02](15.02-原始IO.md) 的 `write_all` 循环同源；
  - `EINTR` 重试 → TLPI Ch21（信号与 `sigaction` 的 `SA_RESTART`）；
  - `ioctl` 的内核侧是 **`unlocked_ioctl` / `compat_ioctl`**（LDD3 Ch6），
    [15.04](15.04-ioctl.md) 的命令号位域就是 `copy_to/from_user` 之外的另一半协议；
  - `FIONREAD` 对文件/目录也成功 → 内核里 `file_operations` 的每个实例
    自己决定响应哪些命令，不响应就返回 `-ENOTTY`。

## 实验复现

```sh
# ① argc/argv + atoi vs strtol
clang -O1 -Wall -o arg arg.c && ./arg a b 3
clang -O1 -Wall -o cv  cv.c  && ./cv

# ② 原始 I/O：无缓冲、errno、权限
clang -O1 -Wall -o raw raw.c && ./raw

# ③ 短读
clang -O1 -Wall -o sr sr.c && echo "hello" | ./sr

# ④ 二进制 / 文本模式
clang -O1 -Wall -o bm bm.c && ./bm && od -An -tx1 bm.bin bm.txt

# ⑤ 二进制里的 0x00
clang -O1 -Wall -o bm2 bm2.c && ./bm2 && od -An -tx1 blk.bin

# ⑥ ioctl：三种 errno + pty 下的成功
clang -O1 -Wall -o io2 io2.c && ./io2 && echo "hello" | ./io2 && script -q /dev/null ./io2

# ⑦ ioctl 命令号位域
clang -O1 -Wall -o cmd cmd.c && ./cmd
```
