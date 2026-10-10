#!/usr/bin/env bash
# =============================================================================
# tools/dbg.sh —— 一条命令起「openocd + gdb」
#
# 书里点一下 Debug 按钮，背后其实是三个进程（见 01-stm32/book-notes/02-ide/2.1 Q1）：
#     gdb（主机）──RSP/TCP── OpenOCD（主机）──USB── ST-Link ──SWD── 芯片
# 这个脚本把前两个拉起来；第三个在板子上，不用管。
#
# 用法：
#   tools/dbg.sh labs/01-hello/hello.elf                  在 Reset_Handler 停下
#   tools/dbg.sh hello.elf --break main                   换断点
#   tools/dbg.sh hello.elf --board f103c8t6
#   tools/dbg.sh --attach                                 复用已在跑的 openocd
#   tools/dbg.sh hello.elf --batch -ex "info registers"   非交互，跑完就退
#
# 如果 :3333 上已经有 openocd（比如另一个终端里 `make openocd`），
# 脚本会直接复用，退出时也不会把别人的 openocd 杀掉。
#
# 进了 gdb 之后最常用的五条：
#   monitor reset halt     复位并停住（不是 continue）
#   load                   把 elf 下载进去（等价于 openocd 的 program）
#   break main / continue
#   next / step / info registers
#   x/4xw 0x08000000       裸机上这是最重要的"printf"
# =============================================================================

set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FILE=""
BOARD="f103rb"
BREAK="Reset_Handler"
BATCH=0
ATTACH=0
declare -a EXTRA_EX=()

while [ $# -gt 0 ]; do
  case "$1" in
    --board|-b) BOARD="${2:-}"; shift ;;
    --break)    BREAK="${2:-}"; shift ;;
    --attach)   ATTACH=1 ;;
    --batch)    BATCH=1 ;;
    -ex)        EXTRA_EX+=(-ex "${2:-}"); shift ;;
    -h|--help)  sed -n '2,25p' "$0" | sed 's/^#\{1,\} \{0,1\}//'; exit 0 ;;
    -*)         printf '未知参数：%s\n' "$1" >&2; exit 2 ;;
    *)          FILE="$1" ;;
  esac
  shift
done

if [ -z "$FILE" ] && [ "$ATTACH" -eq 0 ]; then
  printf '用法：tools/dbg.sh <文件.elf> [--board 板子] [--break 符号] [--batch]\n' >&2
  printf '      tools/dbg.sh --attach    只连已在跑的 openocd\n' >&2
  exit 2
fi
if [ -n "$FILE" ] && [ ! -f "$FILE" ]; then
  printf '文件不存在：%s\n' "$FILE" >&2
  exit 2
fi

detect_all

# ---------------------------------------------------------------- 检查依赖
RC=0
if [ -z "$TOOL_GDB" ]; then
  bad "找不到 arm-none-eabi-gdb"
  note "只有调试需要它；编译链不用 GCC（见 01-stm32/00-toolchain-clang）"
  RC=1
fi

CFG=""
if [ "$ATTACH" -eq 0 ]; then
  if [ -z "$TOOL_OPENOCD" ]; then
    bad "找不到 openocd"
    RC=1
  else
    CFG=$(board_get "$BOARD" BOARD_OPENOCD_CFG) || {
      printf '找不到 boards/%s.mk；可选：%s\n' "$BOARD" "$(boards_list)" >&2
      exit 2
    }
  fi
fi
[ "$RC" -ne 0 ] && exit 1

# ---------------------------------------------------------------- 端口占用？
PORT=3333
port_open() { (echo > "/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

OUR_OCD=""
cleanup() {
  if [ -n "$OUR_OCD" ]; then
    printf '\n收尾：关掉 OpenOCD（pid %s）\n' "$OUR_OCD"
    kill "$OUR_OCD" 2>/dev/null
    wait "$OUR_OCD" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

LOG="${TMPDIR:-/tmp}/stm32-dbg-openocd.log"

if port_open "$PORT"; then
  note ":$PORT 上已经有 OpenOCD，直接复用（退出时不会动它）"
else
  if [ "$ATTACH" -eq 1 ]; then
    bad ":$PORT 上没有 OpenOCD，--attach 无从连起"
    note "先在一个终端里跑：make openocd"
    exit 1
  fi
  OCD="$TOOL_OPENOCD"
  [ -n "$TOOL_OPENOCD_SCRIPTS" ] && OCD="$OCD -s $TOOL_OPENOCD_SCRIPTS"
  printf '起 OpenOCD（日志：%s）\n' "$LOG"
  # shellcheck disable=SC2086
  $OCD -f "$CFG" >"$LOG" 2>&1 &
  OUR_OCD=$!

  # 等 :3333 起来（最多 10 秒）。等端口而不是固定 sleep——
  # ST-Link 枚举快慢跟 USB 口、集线器都有关系。
  i=0
  while [ "$i" -lt 50 ]; do
    port_open "$PORT" && break
    if ! kill -0 "$OUR_OCD" 2>/dev/null; then
      bad "OpenOCD 启动即退出，日志尾部："
      sed 's/^/       /' "$LOG" | tail -10
      OUR_OCD=""
      exit 1
    fi
    i=$((i + 1))
    sleep 0.2
  done

  if port_open "$PORT"; then
    ok "OpenOCD 就绪（pid $OUR_OCD，:$PORT）"
    grep -i -e 'STLINK' -e 'DPIDR' -e 'Cortex-M' "$LOG" 2>/dev/null | sed 's/^/       /' | head -3
  else
    bad "等不到 :$PORT，日志尾部："
    sed 's/^/       /' "$LOG" | tail -10
    exit 1
  fi
fi

# ---------------------------------------------------------------- gdb
declare -a G=()
[ -n "$FILE" ] && G+=("$FILE")
[ "$BATCH" -eq 1 ] && G+=(-batch)
G+=(-ex "target extended-remote :$PORT")
G+=(-ex "monitor reset halt")
[ -n "$BREAK" ] && G+=(-ex "break $BREAK")
[ -n "$FILE" ]  && G+=(-ex "continue")
if [ "${#EXTRA_EX[@]}" -gt 0 ]; then G+=("${EXTRA_EX[@]}"); fi

printf '\n连 gdb → %s\n' "${FILE:-（无 elf，纯 attach）}"
printf '  断点：%s\n\n' "${BREAK:-（无）}"

"$TOOL_GDB" "${G[@]}"
RC=$?

if [ "$RC" -ne 0 ]; then
  bad "gdb 退出码 $RC"
  note "排障：OpenOCD 那层的日志在 $LOG"
fi
exit "$RC"
