#!/usr/bin/env bash
# =============================================================================
# tools/flash.sh —— 烧录包装
#
# 把 openocd 那串参数收进一个命令，顺带替你决定"要不要给 Flash 起始地址"：
#   .elf → openocd 自己解析 program header，不用地址
#   .bin → 纯字节流没有地址信息，必须显式给（这里从 boards/<板子>.mk 取）
#
# 用法：
#   tools/flash.sh labs/01-hello/hello.bin              默认板子 f103rb
#   tools/flash.sh labs/01-hello/hello.elf              烧 .elf（带校验）
#   tools/flash.sh out.bin --board f103c8t6             指定板子
#   tools/flash.sh out.bin --no-verify                  跳过逐字节校验（快，但别常用）
#
# 注意最后一定要有 exit：少了它 openocd 会一直挂着不退
# （实测第一次两分钟没退出，只能 pkill）。
# =============================================================================

set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FILE=""
BOARD="f103rb"
VERIFY=1
RESET=1

while [ $# -gt 0 ]; do
  case "$1" in
    --board|-b) BOARD="${2:-}"; shift ;;
    --no-verify) VERIFY=0 ;;
    --no-reset)  RESET=0 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^#\{1,\} \{0,1\}//'; exit 0 ;;
    -*) printf '未知参数：%s\n' "$1" >&2; exit 2 ;;
    *)  FILE="$1" ;;
  esac
  shift
done

if [ -z "$FILE" ]; then
  printf '用法：tools/flash.sh <文件.elf|文件.bin> [--board 板子] [--no-verify]\n' >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '文件不存在：%s\n' "$FILE" >&2
  printf '先编译：cd 到 lab 目录跑 make\n' >&2
  exit 2
fi

detect_all

if [ -z "$TOOL_OPENOCD" ]; then
  bad "找不到 openocd"
  note "跑 bash tools/env.sh 看怎么办；或先 source tools/env.sh --export"
  exit 1
fi

CFG=$(board_get "$BOARD" BOARD_OPENOCD_CFG) || {
  printf '找不到 boards/%s.mk；可选：%s\n' "$BOARD" "$(boards_list)" >&2
  exit 2
}
ORIGIN=$(board_get "$BOARD" BOARD_FLASH_ORIGIN)
BNAME=$(board_get "$BOARD" BOARD_NAME)

case "$(printf '%s' "$FILE" | tr '[:upper:]' '[:lower:]')" in
  *.elf|*.axf) TARGET_SPEC="$FILE" ; KIND="ELF（地址来自 program header）" ;;
  *.bin)       TARGET_SPEC="$FILE $ORIGIN" ; KIND="BIN（地址取 $ORIGIN）" ;;
  *.hex)       TARGET_SPEC="$FILE" ; KIND="HEX（地址在文件里）" ;;
  *)           TARGET_SPEC="$FILE $ORIGIN" ; KIND="未知格式，按 BIN 处理" ;;
esac

printf '\n烧录 %s\n' "$FILE"
printf '  板子   %s（%s）\n' "$BOARD" "$BNAME"
printf '  格式   %s\n' "$KIND"
printf '  配置   %s\n' "$CFG"
printf '\n'

ACTIONS="program $TARGET_SPEC"
[ "$VERIFY" -eq 1 ] && ACTIONS="$ACTIONS verify"
[ "$RESET"  -eq 1 ] && ACTIONS="$ACTIONS reset"
ACTIONS="$ACTIONS exit"

OCD="$TOOL_OPENOCD"
[ -n "$TOOL_OPENOCD_SCRIPTS" ] && OCD="$OCD -s $TOOL_OPENOCD_SCRIPTS"

# shellcheck disable=SC2086
$OCD -f "$CFG" -c "$ACTIONS"
RC=$?

if [ "$RC" -eq 0 ]; then
  ok "烧录完成"
  note "看板子上的 LED；或 make probe 只读回读一遍确认"
else
  bad "openocd 退出码 $RC"
  note "分层排查：STLINK（USB）→ DPIDR（SWD）→ Cortex-M（内核）→ device id（Flash），哪行没出现问题就在那层"
fi
exit "$RC"
