#!/usr/bin/env bash
# =============================================================================
# tools/lib.sh —— 工具台的公共部分
#
# 只做两件事：
#   1. 跨平台找工具（PATH 优先，再按平台惯例翻常见安装位置）
#   2. 统一的输出格式（[ OK ] / [FAIL] / [WARN] / [SKIP]）
#
# 被 env.sh / flash.sh / dbg.sh / newlab.sh 复用。也可以直接 source 到交互 shell：
#     source tools/lib.sh
#     detect_all && echo "$TOOL_CLANG"
#
# 两个必须留在心里的坑：
#   · 候选目录里**有空格**（Windows 的 "C:\Program Files\LLVM\bin"），
#     所以一律用数组传递，绝不能 `for d in $dirs` 那样裸展开——那样会被
#     词切分成 "/c/Program" 和 "Files/LLVM/bin"，于是"装了却找不到"。
#   · 不做 set -e。自检脚本的价值在于把每一层的失败都报告完，而不是第一层就退出。
#
# 兼容 bash 3.2（macOS 自带的那版）：不用 mapfile，数组展开用 ${arr[@]+"${arr[@]}"}。
# =============================================================================

set -u

# ---------------------------------------------------------------- 输出格式
if [ -t 1 ]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_RED=; C_GRN=; C_YEL=; C_DIM=; C_BLD=; C_OFF=
fi

ok()   { printf '  %s[ OK ]%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
bad()  { printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_OFF" "$*"; }
warn() { printf '  %s[WARN]%s %s\n' "$C_YEL" "$C_OFF" "$*"; }
skip() { printf '  %s[SKIP]%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
note() { printf '  %s[ -- ]%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }
hdr()  { printf '\n%s%s%s\n' "$C_BLD" "$*" "$C_OFF"; }

# ---------------------------------------------------------------- 基础判断
have() { command -v "$1" >/dev/null 2>&1; }

# find_tool <可执行名> [候选目录…]
#   PATH 里有就用 PATH 里的；否则按顺序在候选目录里找（兼容 Windows 的 .exe）。
#   找到 → 打印绝对路径；找不到 → 返回 1。
find_tool() {
  local name="$1"; shift
  if have "$name"; then command -v "$name"; return 0; fi
  local d
  for d in ${1+"$@"}; do
    [ -n "$d" ] || continue
    if [ -x "$d/$name" ];     then printf '%s\n' "$d/$name";     return 0; fi
    if [ -x "$d/$name.exe" ]; then printf '%s\n' "$d/$name.exe"; return 0; fi
  done
  return 1
}

# _load_dirs <候选函数名>
#   把 "候选函数输出的目录列表" 去重、过滤掉不存在的，装进全局数组 _DIRS。
#   用 while-read 而不是 for，就是为了对付带空格的路径。
_DIRS=()
_load_dirs() {
  _DIRS=()
  local d
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ -d "$d" ] && _DIRS[${#_DIRS[@]}]="$d"
  done < <("$1" 2>/dev/null | awk '!seen[$0]++')
}

# ---------------------------------------------------------------- 候选目录
# 每行一个目录（不含末尾斜杠）。不存在的目录由 _load_dirs 过滤。
# 平台惯例都是公开事实：macOS 走 brew/官方 tar 包 + 家目录；Windows 走
# Program Files / winget / chocolatey / scoop；Linux 走发行版包管理器。

cand_llvm() {
  local h="${HOME:-}"
  # 显式环境变量最优先
  [ -n "${LLVM_BIN:-}" ] && printf '%s\n' "$LLVM_BIN"
  # conda / micromamba（macOS 上 cdev 环境走这条）
  printf '%s\n' \
    "$h/micromamba/envs/cdev/bin" \
    "$h/mambaforge/envs/cdev/bin" \
    "$h/miniconda3/envs/cdev/bin" \
    "$h/anaconda3/envs/cdev/bin"
  # Homebrew / 系统
  printf '%s\n' /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin /opt/homebrew/bin /usr/local/bin /usr/bin
  # 版本化的私有安装（官方 tar 包解压）
  local d
  for d in "$h"/.local/llvm*/bin "$h"/.local/LLVM*/bin "$h"/opt/llvm*/bin; do printf '%s\n' "$d"; done
  # Windows
  printf '%s\n' \
    "/c/Program Files/LLVM/bin" \
    "/c/Program Files (x86)/LLVM/bin" \
    "$h/AppData/Local/Programs/LLVM/bin" \
    "/c/ProgramData/chocolatey/bin" \
    "$h/scoop/shims"
}

cand_openocd() {
  local h="${HOME:-}"
  [ -n "${OPENOCD:-}" ] && printf '%s\n' "$(dirname "$OPENOCD")"
  printf '%s\n' /opt/homebrew/bin /usr/local/bin /usr/bin
  local d
  for d in "$h"/.local/xpack-openocd-*/bin "$h"/.local/openocd*/bin "$h"/opt/openocd*/bin; do printf '%s\n' "$d"; done
  # Windows
  printf '%s\n' \
    "/c/Program Files/OpenOCD/bin" \
    "/c/Program Files (x86)/OpenOCD/bin" \
    "$h/AppData/Local/Programs/OpenOCD/bin" \
    "/c/ProgramData/chocolatey/bin"
  for d in "$h"/AppData/Local/Microsoft/WinGet/Packages/*OpenOCD*/**/bin \
           "$h"/scoop/apps/openocd/current/bin; do printf '%s\n' "$d"; done
}

cand_gnu_arm() {
  local h="${HOME:-}"
  [ -n "${GCC_ARM_BIN:-}" ] && printf '%s\n' "$GCC_ARM_BIN"
  printf '%s\n' /opt/homebrew/bin /usr/local/bin /usr/bin
  local d
  for d in "$h"/.local/arm-gnu-toolchain-*/bin "$h"/opt/arm-gnu-toolchain-*/bin; do printf '%s\n' "$d"; done
  # Windows：官方安装器默认落在这里（带版本号的一层子目录）
  for d in "/c/Program Files/Arm GNU Toolchain arm-none-eabi"/*/bin \
           "/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi"/*/bin \
           "$h/AppData/Local/Programs/Arm GNU Toolchain arm-none-eabi"/*/bin; do printf '%s\n' "$d"; done
  printf '%s\n' "/c/ProgramData/chocolatey/bin" "$h/scoop/shims"
}

cand_python() {
  local h="${HOME:-}"
  [ -n "${PYTHON:-}" ] && { have "$PYTHON" && printf '%s\n' "$(dirname "$(command -v "$PYTHON")")"; }
  printf '%s\n' /opt/homebrew/bin /usr/local/bin /usr/bin
  local d
  for d in "$h"/micromamba/envs/*/bin "$h"/miniconda3/bin "$h"/anaconda3/bin; do printf '%s\n' "$d"; done
  printf '%s\n' "/c/Python313" "/c/Python312" "/c/Python311" "$h/AppData/Local/Programs/Python/Python313"
}

cand_make() {
  local h="${HOME:-}"
  printf '%s\n' /opt/homebrew/bin /usr/local/bin /usr/bin /bin
  local d
  for d in "$h"/.local/make*/bin "$h"/.local/ezwinports*/bin; do printf '%s\n' "$d"; done
  printf '%s\n' \
    "/c/Program Files/Git/usr/bin" \
    "/c/Program Files/Git/mingw64/bin" \
    "/c/ProgramData/chocolatey/bin" \
    "$h/scoop/shims" \
    "/c/GnuWin32/bin" \
    "/c/Program Files (x86)/GnuWin32/bin"
  for d in /c/Program*/ezwinports*/bin "$h"/AppData/Local/Microsoft/WinGet/Packages/*make*/**/bin; do printf '%s\n' "$d"; done
}

# openocd 的 scripts 目录：xpack 这类"解压即用"的发行版必须有它
# （否则 find 找不到 interface/target 脚本）；brew/apt 装的版本自带编译期搜索路径。
openocd_scripts_dir() {
  local ocd="$1" d
  for d in "$(dirname "$(dirname "$ocd")")/openocd/scripts" \
           "$(dirname "$(dirname "$ocd")")/share/openocd/scripts" \
           "$(dirname "$ocd")/../share/openocd/scripts" \
           /opt/homebrew/share/openocd/scripts \
           /usr/local/share/openocd/scripts \
           /usr/share/openocd/scripts \
           "/c/Program Files/OpenOCD/share/openocd/scripts" \
           "/c/Program Files (x86)/OpenOCD/share/openocd/scripts"; do
    [ -d "$d" ] && { printf '%s\n' "$d"; return 0; }
  done
  return 1
}

# ---------------------------------------------------------------- 板级读取
# board_get <板子名> <变量名>：从 boards/<板子名>.mk 里读一个变量的值。
# 这些 .mk 是给 make 用的纯 `NAME := value` 形式，够 sed 解析；
# 顺手把 $(REPO_ROOT) 展开成真实路径（BOARD_OPENOCD_CFG 里用了它）。
board_get() {
  local root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local mk="$root/boards/$1.mk" v
  [ -f "$mk" ] || return 1
  v=$(sed -n "s/^$2[[:space:]]*:*=[[:space:]]*//p" "$mk" | head -1)
  printf '%s\n' "${v//'$(REPO_ROOT)'/$root}"
}

# boards_list：所有可用板子名（不含 .mk），空格分隔
boards_list() {
  local root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  ls "$root/boards"/*.mk 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.mk$//' | tr '\n' ' '
}

# ---------------------------------------------------------------- 汇总探测
# 探测结果写进这些变量，供 env.sh / flash.sh / dbg.sh / newlab.sh 使用。
TOOL_LLVM_BIN=""
TOOL_CLANG=""
TOOL_LD=""
TOOL_OBJCOPY=""
TOOL_READELF=""
TOOL_SIZE=""
TOOL_NM=""
TOOL_OBJDUMP=""
TOOL_MAKE=""
TOOL_OPENOCD=""
TOOL_OPENOCD_SCRIPTS=""
TOOL_GNU_BIN=""
TOOL_GDB=""
TOOL_PYTHON=""

detect_all() {
  local dir

  # --- LLVM -----------------------------------------------------------------
  _load_dirs cand_llvm
  TOOL_CLANG=$(find_tool clang ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_CLANG=""
  if [ -n "$TOOL_CLANG" ] && ! have clang; then
    TOOL_LLVM_BIN=$(dirname "$TOOL_CLANG")
  fi

  # 兄弟工具优先取与 clang 同目录的那一份——整套必须是同一个 LLVM 版本，
  # 不要出现 clang 22 + ld.lld 15 这种混搭。
  if [ -n "$TOOL_CLANG" ]; then
    dir=$(dirname "$TOOL_CLANG")
    TOOL_LD=$(find_tool ld.lld "$dir")            || TOOL_LD=""
    TOOL_OBJCOPY=$(find_tool llvm-objcopy "$dir") || TOOL_OBJCOPY=""
    TOOL_SIZE=$(find_tool llvm-size "$dir")       || TOOL_SIZE=""
    TOOL_NM=$(find_tool llvm-nm "$dir")           || TOOL_NM=""
    TOOL_OBJDUMP=$(find_tool llvm-objdump "$dir") || TOOL_OBJDUMP=""
    # llvm-readelf 在 Windows 官方包里没有，退到 llvm-readobj（输出格式略不同，
    # 调用方用 sed 同时兼容两种："Machine:" 都有，"Entry point address:" 只有 readelf 有）
    TOOL_READELF=$(find_tool llvm-readelf "$dir") || TOOL_READELF=""
    [ -z "$TOOL_READELF" ] && { TOOL_READELF=$(find_tool llvm-readobj "$dir") || TOOL_READELF=""; }
  fi

  # --- OpenOCD ---------------------------------------------------------------
  if [ -n "${OPENOCD:-}" ]; then
    TOOL_OPENOCD="$OPENOCD"
  else
    _load_dirs cand_openocd
    TOOL_OPENOCD=$(find_tool openocd ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_OPENOCD=""
  fi
  if [ -n "$TOOL_OPENOCD" ]; then
    TOOL_OPENOCD_SCRIPTS=$(openocd_scripts_dir "$TOOL_OPENOCD") || \
      TOOL_OPENOCD_SCRIPTS="${OPENOCD_SCRIPTS:-}"
  fi

  # --- GNU Arm（只有调试的 gdb 需要）----------------------------------------
  _load_dirs cand_gnu_arm
  TOOL_GDB=$(find_tool arm-none-eabi-gdb ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_GDB=""
  if [ -n "$TOOL_GDB" ] && ! have arm-none-eabi-gdb; then
    TOOL_GNU_BIN=$(dirname "$TOOL_GDB")
  fi

  # --- python3 ---------------------------------------------------------------
  _load_dirs cand_python
  TOOL_PYTHON=$(find_tool python3 ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_PYTHON=""
  [ -z "$TOOL_PYTHON" ] && { TOOL_PYTHON=$(find_tool python ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_PYTHON=""; }

  # --- make（构建驱动器本身）-------------------------------------------------
  # Windows 上 make 常常是唯一缺的那件：LLVM 装了、clang 能跑，但没有 make
  # 就串不起构建。GnuWin32 / ezwinports / winget / scoop 都可能有。
  _load_dirs cand_make
  TOOL_MAKE=$(find_tool make ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_MAKE=""
  [ -z "$TOOL_MAKE" ] && { TOOL_MAKE=$(find_tool gmake ${_DIRS[@]+"${_DIRS[@]}"}) || TOOL_MAKE=""; }
}
