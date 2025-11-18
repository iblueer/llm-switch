#!/usr/bin/env bash
# llm-switch 本地安装脚本
# 使用方式：将项目源码复制到本地，进入 llm-switch 目录后执行 ./install-locally.sh

set -eu
[ "${LLM_SWITCH_DEBUG:-0}" = "1" ] && set -x

on_err() {
  local code=$?
  echo "✗ 安装失败 (exit=$code)。请检查权限或路径。" >&2
  exit "$code"
}
trap 'on_err' ERR

echo ">>> 开始安装 llm-switch ..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[Info] 源码目录: $SCRIPT_DIR"

if [ ! -f "$SCRIPT_DIR/llm-switch.zsh" ] || [ ! -f "$SCRIPT_DIR/llm-switch.bash" ]; then
  echo "✗ 错误: 缺少 llm-switch 核心脚本。请确认以下文件存在:" >&2
  echo "  - llm-switch.zsh" >&2
  echo "  - llm-switch.bash" >&2
  exit 1
fi

INSTALL_ROOT="$HOME/.llm-switch"
BIN_DIR="$INSTALL_ROOT/bin"

SHELL_NAME="$(basename "${LLM_SWITCH_SHELL:-${SHELL:-}}")"
case "$SHELL_NAME" in
  bash) INIT_FILE="$INSTALL_ROOT/init.bash" ;;
  *) SHELL_NAME=zsh; INIT_FILE="$INSTALL_ROOT/init.zsh" ;;
esac

PROJECT_ID="${LLM_SWITCH_PROJECT_ID:-iblueer/zsh-claude-tools/llm-switch}"
BEGIN_MARK="# >>> ${PROJECT_ID} BEGIN (managed) >>>"
END_MARK="# <<< ${PROJECT_ID} END   <<<"

echo "[Step 0] 创建安装目录：$INSTALL_ROOT"
mkdir -p "$BIN_DIR"

echo "[Step 1] 复制脚本到 $BIN_DIR"
cp -f "$SCRIPT_DIR/llm-switch.zsh" "$BIN_DIR/llm-switch.zsh"
cp -f "$SCRIPT_DIR/llm-switch.bash" "$BIN_DIR/llm-switch.bash"

: "${LLM_SWITCH_HOME:="$HOME/.llm-switch"}"
ENV_DIR="$LLM_SWITCH_HOME/envs"

echo "[Step 2] 准备环境目录：$ENV_DIR"
mkdir -p "$ENV_DIR"

DEFAULT_ENV="$ENV_DIR/default.env"
if [ ! -f "$DEFAULT_ENV" ]; then
  echo "[Step 2] 创建默认环境：$DEFAULT_ENV"
cat >"$DEFAULT_ENV" <<'E'
# llm-switch 默认环境模板
export LLM_PROVIDER=""
export LLM_API_KEY=""
export LLM_BASE_URL=""
export LLM_MODEL_NAME=""
E
  chmod 600 "$DEFAULT_ENV" 2>/dev/null || true
fi

echo "[Step 3] 生成 init：$INIT_FILE"
if [ "$SHELL_NAME" = "bash" ]; then
  cat >"$INIT_FILE" <<'EINIT'
# llm-switch init for bash (auto-generated)
: ${LLM_SWITCH_HOME:="$HOME/.llm-switch"}
if [ -f "$HOME/.llm-switch/bin/llm-switch.bash" ]; then
  . "$HOME/.llm-switch/bin/llm-switch.bash"
fi
EINIT
else
  cat >"$INIT_FILE" <<'EINIT'
# llm-switch init for zsh (auto-generated)
: ${LLM_SWITCH_HOME:="$HOME/.llm-switch"}

case "$-" in
  *i*)
    if [ -f "$HOME/.llm-switch/bin/llm-switch.zsh" ]; then
      . "$HOME/.llm-switch/bin/llm-switch.zsh"
    fi
    ;;
esac
EINIT
fi

if [ "$SHELL_NAME" = "bash" ]; then
  RC="$HOME/.bashrc"
  echo "[Step 4] 更新 Bash 配置：$RC"
else
  if [ -n "${ZDOTDIR:-}" ]; then
    RC="$ZDOTDIR/.zshrc"
  else
    RC="$HOME/.zshrc"
  fi
  echo "[Step 4] 更新 Zsh 配置：$RC"
fi

[ -f "$RC" ] || : >"$RC"

TMP_RC="$(mktemp)"
awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
  BEGIN { skip=0 }
  $0 == begin { skip=1; next }
  $0 == end   { skip=0; next }
  skip==0 { print }
' "$RC" >"$TMP_RC"

{
  printf "%s\n" "$BEGIN_MARK"
  if [ "$SHELL_NAME" = "bash" ]; then
    printf '%s\n' 'source "$HOME/.llm-switch/init.bash"'
  else
    printf '%s\n' 'source "$HOME/.llm-switch/init.zsh"'
  fi
  printf "%s\n" "$END_MARK"
} >>"$TMP_RC"

LC_ALL=C tail -c 1 "$TMP_RC" >/dev/null 2>&1 || printf '\n' >>"$TMP_RC"

mv "$TMP_RC" "$RC"

echo
echo ">>> llm-switch 安装完成 🎉"
echo "安装目录：$INSTALL_ROOT"
echo "环境目录：$ENV_DIR"
echo
echo "请执行： source \"$RC\""
echo "然后运行： llm-switch list"
