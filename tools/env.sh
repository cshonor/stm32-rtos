#!/usr/bin/env bash
# =============================================================================
# tools/env.sh —— 工具台自检：一条命令回答「这台机器现在能不能做嵌入式」
#
# 这不是把 `command -v` 挨个敲一遍，而是把 01-stm32/book-notes/01-hello-world/1.2
# 里那张"分层确认表"变成可执行脚本：**每一层都真跑一次**，
# 哪一层没过，问题就在那一层，不要跳层猜。
#
# 分层：
#   [1] make      构建驱动器（工具台的入口，缺了它一切都要手敲）
#   [2] 编译器    clang 能不能产出 armv7m 的目标文件
#   [3] 链接器    ld.lld 能不能吃 GNU 链接脚本、产出可执行 ELF
#   [4] 转换      llvm-objcopy 能不能把 ELF 抽成裸 .bin
#   [5] 主机脚本  python3（check_vectors.py 这类断言用）
#   [6] 调试服务器 openocd（烧录/调试）
#   [7] 调试器    arm-none-eabi-gdb（源码级调试）
#   [8] 硬件链路  实际打开一次连接（只有加 --hw 才跑，要插着板子）
#
# 用法：
#   bash tools/env.sh                    报告（默认板子 f103rb）
#   bash tools/env.sh --board f407zg     指定板子（影响 -mcpu 与 OpenOCD 配置）
#   bash tools/env.sh --hw               加上第 8 层
#   source tools/env.sh --export         把探测到的工具目录写进当前 shell 的 PATH
#   eval "$(bash tools/env.sh --export)" 同上，但只对当前命令生效
#
# 退出码：0 = 编译链完整可用（调试链缺失记 WARN，不算硬伤）；1 = 有硬伤
# =============================================================================

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)

# shellcheck source=lib.sh
. "$HERE/lib.sh"

_IS_SOURCED=0
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0:-}" ]; then
  _IS_SOURCED=1
fi

BOARD=f103rb
DO_EXPORT=0
DO_HW=0

while [ $# -gt 0 ]; do
  case "$1" in
    --export) DO_EXPORT=1 ;;
    --hw)     DO_HW=1 ;;
    --board)  BOARD="${2:-}"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
      ${_IS_SOURCED:+return} 0 2>/dev/null || exit 0 ;;
    *) printf '未知参数: %s（--help 看用法）\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------- 板级信息
BOARD_MK="$REPO_ROOT/boards/$BOARD.mk"
if [ ! -f "$BOARD_MK" ]; then
  printf '找不到 boards/%s.mk\n可选板子：%s\n' "$BOARD" "$(boards_list)" >&2
  exit 2
fi

board_field() { sed -n "s/^$1[[:space:]]*:*=[[:space:]]*//p" "$BOARD_MK" | head -1; }
B_NAME=$(board_field BOARD_NAME)
B_CPU=$(board_field BOARD_CPU)
B_TRIPLE=$(board_field BOARD_TRIPLE)
B_OCD=$(board_field BOARD_OPENOCD_CFG)
B_OCD=${B_OCD//'$(REPO_ROOT)'/$REPO_ROOT}

# ---------------------------------------------------------------- 环境探测
detect_all

FAIL=0

printf '\n%s\n' "=========== STM32 工具台自检 ==========="
printf '仓库   %s\n' "$REPO_ROOT"
printf '板子   %s（%s / %s）\n' "$BOARD" "$B_NAME" "$B_CPU"
printf '主机   %s\n' "$(uname -s 2>/dev/null || echo unknown)"
printf '时间   %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/stm32-env-XXXXXX") || { printf '无法创建临时目录\n' >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- [0] 工具台自足
hdr "工具台自身完整性"
_scaffold_missing=0
for f in "$REPO_ROOT/mk/arm-clang.mk" "$REPO_ROOT/mk/locate-tools.mk" \
         "$REPO_ROOT/tools/selftest/min.c" "$REPO_ROOT/tools/selftest/min.ld" \
         "$REPO_ROOT/tools/templates/bare-metal/Makefile" "$BOARD_MK"; do
  [ -f "$f" ] || { bad "缺文件：${f#"$REPO_ROOT"/}"; _scaffold_missing=1; }
done
if [ "$_scaffold_missing" -eq 0 ]; then
  ok "mk/ boards/ tools/ 齐备，板子 $(boards_list)"
fi
[ "$_scaffold_missing" -eq 1 ] && FAIL=1

# ---------------------------------------------------------------- [1/7] make
hdr "[1/7] 构建驱动器 —— make"
MAKE_OK=0
if [ -n "$TOOL_MAKE" ]; then
  ok "$TOOL_MAKE"
  note "$("$TOOL_MAKE" --version 2>&1 | head -1)"
  note "工具台的入口是 make；不装它也能做，但每次都要手敲 clang/ld.lld/objcopy 三行"
  MAKE_OK=1
else
  bad "找不到 make"
  note "macOS：预装或 brew install make（注意叫 gmake）"
  note "Windows：winget install ezwinports.make 或 GnuWin32.Make；scoop 用 scoop install make"
  FAIL=1
fi

# ---------------------------------------------------------------- [2/7] 编译器
hdr "[2/7] 编译器 —— clang --target=$B_TRIPLE -mcpu=$B_CPU"
CC_OK=0
if [ -z "$TOOL_CLANG" ]; then
  bad "找不到 clang"
  note "macOS：brew install llvm，或用 micromamba 的 cdev 环境"
  note "Windows：winget install LLVM.LLVM（装完新开终端让 PATH 生效）"
  FAIL=1
elif "$TOOL_CLANG" --target="$B_TRIPLE" -mcpu="$B_CPU" -mthumb \
       -ffreestanding -fno-builtin -fno-common -c "$HERE/selftest/min.c" \
       -o "$TMP/min.o" 2>"$TMP/cc.err"; then
  MACHINE=$("$TOOL_READELF" -h "$TMP/min.o" 2>/dev/null | sed -n 's/.*Machine:[[:space:]]*//p' | head -1)
  ok "$TOOL_CLANG"
  note "$("$TOOL_CLANG" --version 2>&1 | head -1)"
  note "产出 min.o，ELF machine = ${MACHINE:-未知}"
  CC_OK=1
else
  bad "clang 在，但编译 armv7m 目标失败"
  sed 's/^/       /' "$TMP/cc.err" | head -6
  note "常见原因：装的是不带 ARM 后端的精简 LLVM，或 --target 拼写有误"
  FAIL=1
fi

# ---------------------------------------------------------------- [3/7] 链接器
hdr "[3/7] 链接器 —— ld.lld -T min.ld"
LD_OK=0
if [ "$CC_OK" -ne 1 ]; then
  skip "上一层没有目标文件，跳过"
elif [ -z "$TOOL_LD" ]; then
  bad "找不到 ld.lld"
  note "macOS 自带的 /usr/bin/ld 是 Mach-O 链接器，报 'unknown option: -T' —— 要的是 LLVM 的 ld.lld"
  FAIL=1
elif "$TOOL_LD" -T "$HERE/selftest/min.ld" -o "$TMP/min.elf" "$TMP/min.o" 2>"$TMP/ld.err"; then
  # llvm-readelf 打 "Entry point address:"，llvm-readobj 打 "Entry:" —— 两种都认
  ENTRY=$("$TOOL_READELF" -h "$TMP/min.elf" 2>/dev/null \
    | sed -n -e 's/.*Entry point address:[[:space:]]*//p' -e 's/^[[:space:]]*Entry:[[:space:]]*//p' \
    | head -1)
  ok "$TOOL_LD"
  note "产出 min.elf，入口 = ${ENTRY:-未知}"
  LD_OK=1
else
  bad "链接失败"
  sed 's/^/       /' "$TMP/ld.err" | head -6
  FAIL=1
fi

# ---------------------------------------------------------------- [4/7] 转换
hdr "[4/7] 转换 —— llvm-objcopy -O binary"
if [ "$LD_OK" -ne 1 ]; then
  skip "上一层没有 ELF，跳过"
elif [ -z "$TOOL_OBJCOPY" ]; then
  bad "找不到 llvm-objcopy"
  FAIL=1
elif "$TOOL_OBJCOPY" -O binary "$TMP/min.elf" "$TMP/min.bin" 2>"$TMP/oc.err" && [ -s "$TMP/min.bin" ]; then
  ok "$TOOL_OBJCOPY"
  note "min.elf → min.bin，$(wc -c < "$TMP/min.bin" | tr -d ' ') 字节（烧录器要的是这个，不是 .elf）"
else
  bad "抽 .bin 失败"
  sed 's/^/       /' "$TMP/oc.err" | head -6
  FAIL=1
fi

# ---------------------------------------------------------------- [5/7] 主机脚本
hdr "[5/7] 主机侧脚本 —— python3（check_vectors.py 用）"
if [ -n "$TOOL_PYTHON" ]; then
  ok "$TOOL_PYTHON —— $("$TOOL_PYTHON" -V 2>&1 | head -1)"
  note "macOS 上不要用 /usr/bin/python3：会弹 Xcode 许可协议"
else
  warn "找不到 python3 —— 向量表断言（make vectors）这类主机侧自检会跑不了"
  note "编译/烧录/调试不受影响"
fi

# ---------------------------------------------------------------- [6/7] openocd
hdr "[6/7] 调试服务器 —— openocd"
if [ -n "$TOOL_OPENOCD" ]; then
  ok "$TOOL_OPENOCD"
  note "$("$TOOL_OPENOCD" --version 2>&1 | head -1)"
  if [ -n "$TOOL_OPENOCD_SCRIPTS" ]; then
    note "scripts 搜索根：$TOOL_OPENOCD_SCRIPTS"
  else
    warn "没找到 scripts 目录 —— 若是 xpack 解压版，请显式设 OPENOCD_SCRIPTS"
  fi
  if [ -f "$B_OCD" ]; then
    ok "板级配置：${B_OCD#"$REPO_ROOT"/}"
  else
    bad "板级配置不存在：$B_OCD"
    FAIL=1
  fi
else
  warn "找不到 openocd —— 只能编译，不能烧录/调试"
  note "macOS：brew install openocd，或下 xPack 的 darwin-arm64 包解压到家目录"
  note "Windows：winget install OpenOCD（或 xpack-openocd）"
fi

# ---------------------------------------------------------------- [7/7] gdb
hdr "[7/7] 调试器 —— arm-none-eabi-gdb"
if [ -n "$TOOL_GDB" ]; then
  ok "$TOOL_GDB"
  note "$("$TOOL_GDB" --version 2>&1 | head -1)"
else
  warn "找不到 arm-none-eabi-gdb —— 能烧录，但没有源码级单步"
  note "只有调试需要它；编译链完全不用 GCC（见 01-stm32/00-toolchain-clang）"
fi

# ---------------------------------------------------------------- [8] 硬件
if [ "$DO_HW" -eq 1 ]; then
  hdr "[8] 硬件链路 —— 真的打开一次连接"
  if [ -z "$TOOL_OPENOCD" ]; then
    bad "没有 openocd，跳过"
  else
    OCD_CMD="$TOOL_OPENOCD"
    [ -n "$TOOL_OPENOCD_SCRIPTS" ] && OCD_CMD="$OCD_CMD -s $TOOL_OPENOCD_SCRIPTS"
    RUNNER=""
    have timeout && RUNNER=timeout 20
    if $RUNNER $OCD_CMD -f "$B_OCD" \
         -c "init" -c "halt" -c "wait_halt 1000" -c "reg pc" -c "shutdown" \
         >"$TMP/ocd.log" 2>&1; then
      ok "OpenOCD 打开连接成功"
      if grep -qi 'STLINK' "$TMP/ocd.log"; then
        ok "USB 层：$(grep -i 'STLINK' "$TMP/ocd.log" | head -1 | sed 's/^[^:]*: *//')"
      else
        warn "日志里没出现 STLINK —— 换个调试器配置试试（stlink.cfg ↔ stlink-v2.cfg）"
      fi
      if grep -qi 'DPIDR' "$TMP/ocd.log"; then
        ok "SWD 层：$(grep -i 'DPIDR' "$TMP/ocd.log" | head -1 | sed 's/^[^:]*: *//')"
      else
        warn "日志里没有 DPIDR —— 检查 SWCLK/SWDIO/GND 接线、板子供电、NRST 是否被拉低"
      fi
      if grep -qi 'Cortex-M' "$TMP/ocd.log"; then
        ok "内核：$(grep -i 'Cortex-M' "$TMP/ocd.log" | head -1 | sed 's/^[^:]*: *//')"
      else
        warn "没认到内核 —— target 脚本可能不匹配这颗芯片"
      fi
      grep -i 'pc' "$TMP/ocd.log" | head -1 | sed 's/^/        /'
    else
      bad "连不上（日志见下）"
      sed 's/^/       /' "$TMP/ocd.log" | tail -8
      FAIL=1
    fi
  fi
fi

# ---------------------------------------------------------------- 导出
if [ "$DO_EXPORT" -eq 1 ]; then
  ADD=""
  [ -n "$TOOL_LLVM_BIN" ] && ADD="$TOOL_LLVM_BIN:$ADD"
  [ -n "$TOOL_GNU_BIN" ]  && ADD="$TOOL_GNU_BIN:$ADD"
  [ -n "$TOOL_MAKE" ]     && ADD="$(dirname "$TOOL_MAKE"):$ADD"
  [ -n "$TOOL_OPENOCD" ]  && ADD="$(dirname "$TOOL_OPENOCD"):$ADD"
  [ -n "$ADD" ] && ADD="${ADD%:}"
  if [ "$_IS_SOURCED" -eq 1 ]; then
    [ -n "$ADD" ] && PATH="$ADD:$PATH"
    [ -n "$TOOL_LLVM_BIN" ] && LLVM_BIN="$TOOL_LLVM_BIN"
    [ -n "$TOOL_OPENOCD" ]  && OPENOCD="$TOOL_OPENOCD"
    [ -n "$TOOL_OPENOCD_SCRIPTS" ] && OPENOCD_SCRIPTS="$TOOL_OPENOCD_SCRIPTS"
    [ -n "$TOOL_GNU_BIN" ]  && GCC_ARM_BIN="$TOOL_GNU_BIN"
    export PATH LLVM_BIN OPENOCD OPENOCD_SCRIPTS GCC_ARM_BIN
    hdr "已写入当前 shell"
    note "PATH 前置：${ADD:-（无需追加，工具都已在 PATH 上）}"
    note "导出：LLVM_BIN=${LLVM_BIN:-} OPENOCD=${OPENOCD:-} OPENOCD_SCRIPTS=${OPENOCD_SCRIPTS:-} GCC_ARM_BIN=${GCC_ARM_BIN:-}"
  else
    printf '\n# 复制下面这行到 shell 里，或改用 source tools/env.sh --export\n'
    [ -n "$ADD" ] && printf 'export PATH="%s:$PATH"\n' "$ADD"
    [ -n "$TOOL_LLVM_BIN" ] && printf 'export LLVM_BIN="%s"\n' "$TOOL_LLVM_BIN"
    [ -n "$TOOL_OPENOCD" ]  && printf 'export OPENOCD="%s"\n' "$TOOL_OPENOCD"
    [ -n "$TOOL_OPENOCD_SCRIPTS" ] && printf 'export OPENOCD_SCRIPTS="%s"\n' "$TOOL_OPENOCD_SCRIPTS"
    [ -n "$TOOL_GNU_BIN" ]  && printf 'export GCC_ARM_BIN="%s"\n' "$TOOL_GNU_BIN"
  fi
fi

# ---------------------------------------------------------------- 结论
hdr "=========== 结论 ==========="
if [ "$FAIL" -eq 0 ]; then
  printf '  %s编译链完整可用。%s\n' "$C_GRN" "$C_OFF"
  printf '  下一步：\n'
  printf '    source tools/env.sh --export      # 工具不在 PATH 时先做这一步\n'
  printf '    cd labs/01-hello && make          # 编一个最小的\n'
  printf '    make BOARD=%s flash               # 插上板子再烧\n' "$BOARD"
  printf '    bash tools/env.sh --hw            # 想确认硬件链路就加这一层\n'
else
  printf '  %s上面有 [FAIL]，先把那一层修掉再往下走。%s\n' "$C_RED" "$C_OFF"
  printf '  排障口诀：哪一层没出现，问题就在那一层（见 01-stm32/book-notes/01-hello-world/1.2 的分层表）。\n'
fi
printf '\n'

exit "$FAIL"
