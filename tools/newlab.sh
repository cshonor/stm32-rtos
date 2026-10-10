#!/usr/bin/env bash
# =============================================================================
# tools/newlab.sh —— 生成一个新实验的骨架
#
# 从 tools/templates/bare-metal/ 拷一份出来，按板子把链接脚本的内存布局、
# Makefile 里的 BOARD、README 的标题全部填好。生成完 `make` 就能出 .bin。
#
# 用法：
#   tools/newlab.sh labs/02-uart                       默认板子 f103rb
#   tools/newlab.sh 01-stm32/04-uart --board f103c8t6
#   tools/newlab.sh labs/03-x --target probe_uart      产物名与目录名不同时用
#   tools/newlab.sh labs/04-x --force                  目录已存在且非空时覆盖
#
# 生成之后要自己改的两处（脚本不猜）：
#   1. main.c 顶部的 LED_BASE / LED_PIN / LED_ACTIVE_LOW —— 模板里带三块板子的取值注释
#   2. README.md 的"这个实验要回答什么" —— 一句话写清要验证的机制
# =============================================================================

set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"

DEST=""
BOARD="f103rb"
TARGET=""
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --board|-b) BOARD="${2:-}"; shift ;;
    --target|-t) TARGET="${2:-}"; shift ;;
    --force|-f) FORCE=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^#\{1,\} \{0,1\}//'; exit 0 ;;
    -*) printf '未知参数：%s\n' "$1" >&2; exit 2 ;;
    *) DEST="$1" ;;
  esac
  shift
done

if [ -z "$DEST" ]; then
  printf '用法：tools/newlab.sh <目录> [--board 板子] [--target 产物名]\n' >&2
  printf '可选板子：%s\n' "$(boards_list)" >&2
  exit 2
fi

# ---------------------------------------------------------------- 板级信息
if [ ! -f "$REPO_ROOT/boards/$BOARD.mk" ]; then
  printf '找不到 boards/%s.mk；可选：%s\n' "$BOARD" "$(boards_list)" >&2
  exit 2
fi
B_NAME=$(board_get "$BOARD" BOARD_NAME)
B_FLASH_O=$(board_get "$BOARD" BOARD_FLASH_ORIGIN)
B_FLASH_S=$(board_get "$BOARD" BOARD_FLASH_SIZE)
B_RAM_O=$(board_get "$BOARD" BOARD_RAM_ORIGIN)
B_RAM_S=$(board_get "$BOARD" BOARD_RAM_SIZE)
TEMPLATE="$HERE/templates/bare-metal"

[ -d "$TEMPLATE" ] || { printf '模板目录不存在：%s\n' "$TEMPLATE" >&2; exit 2; }

# ---------------------------------------------------------------- 目标路径
case "$DEST" in
  /*) ABS="$DEST" ;;
  *)  ABS="$REPO_ROOT/$DEST" ;;
esac
ABS=$(cd "$(dirname "$ABS")" 2>/dev/null && pwd)/$(basename "$ABS") || {
  printf '父目录不存在：%s\n' "$(dirname "$ABS")" >&2
  exit 2
}
case "$ABS" in
  "$REPO_ROOT"/*) ;;
  *) printf '为了保持工具台自足，目标必须建在仓库内：%s\n' "$REPO_ROOT" >&2; exit 2 ;;
esac

REL=${ABS#"$REPO_ROOT"/}
[ -z "$TARGET" ] && TARGET=$(basename "$ABS")

# 到仓库根的相对深度 → include 用的 ../..
DEPTH=$(printf '%s' "$REL" | awk -F/ '{print NF}')
MK_REL=$(awk -v n="$DEPTH" 'BEGIN{s="";for(i=0;i<n;i++)s=s"../";print substr(s,1,length(s)-1)}')

if [ -e "$ABS" ]; then
  if [ "$FORCE" -ne 1 ] && [ -n "$(ls -A "$ABS" 2>/dev/null)" ]; then
    printf '目录已存在且非空：%s\n' "$ABS" >&2
    printf '确认要覆盖就加 --force\n' >&2
    exit 2
  fi
fi
mkdir -p "$ABS" || exit 1

# ---------------------------------------------------------------- 生成
printf '\n生成骨架：%s\n' "$REL"
printf '  板子   %s（%s）\n' "$BOARD" "$B_NAME"
printf '  产物   %s\n' "$TARGET"
printf '  include %s/mk/arm-clang.mk\n' "$MK_REL"
printf '\n'

fill() {
  local src="$1" dst="$2"
  sed \
    -e "s|@BOARD@|$BOARD|g" \
    -e "s|@BOARD_NAME@|$B_NAME|g" \
    -e "s|@TARGET@|$TARGET|g" \
    -e "s|@FLASH_ORIGIN@|$B_FLASH_O|g" \
    -e "s|@FLASH_SIZE@|$B_FLASH_S|g" \
    -e "s|@RAM_ORIGIN@|$B_RAM_O|g" \
    -e "s|@RAM_SIZE@|$B_RAM_S|g" \
    -e "s|@MK_REL@|$MK_REL|g" \
    "$src" > "$dst"
}

for f in Makefile startup.c main.c linker.ld README.md; do
  if [ -e "$ABS/$f" ] && [ "$FORCE" -ne 1 ]; then
    warn "$f 已存在，跳过（--force 可覆盖）"
  else
    fill "$TEMPLATE/$f" "$ABS/$f"
    ok "$f"
  fi
done

# ---------------------------------------------------------------- 收尾提示
hdr "下一步"
printf '  1. 改 %s/main.c 顶部的 LED_BASE / LED_PIN / LED_ACTIVE_LOW\n' "$REL"
printf '     （模板注释里给了 NUCLEO-F103RB / Blue Pill / F407 三组取值）\n'
printf '  2. 改 %s/README.md 的"这个实验要回答什么"\n' "$REL"
printf '  3. 编译：\n'
printf '       source tools/env.sh --export\n'
printf '       cd %s && make\n' "$REL"
printf '  4. 烧录（插板子）：make flash\n'
printf '\n'
