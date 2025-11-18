#!/usr/bin/env bash
# llm-switch 卸载脚本：移除安装目录以及在 shell 配置文件中自动注入的配置片段。

set -euo pipefail
[ "${LLM_SWITCH_DEBUG:-0}" = "1" ] && set -x

PROJECT_ID="${LLM_SWITCH_PROJECT_ID:-iblueer/zsh-claude-tools/llm-switch}"
BEGIN_MARK="# >>> ${PROJECT_ID} BEGIN (managed) >>>"
END_MARK="# <<< ${PROJECT_ID} END   <<<"
INSTALL_ROOT="${LLM_SWITCH_HOME:-$HOME/.llm-switch}"
RC_ZSH="${ZDOTDIR:-$HOME}/.zshrc"
RC_BASH="$HOME/.bashrc"

remove_marked_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    BEGIN { skip=0 }
    $0 == begin { skip=1; next }
    $0 == end   { skip=0; next }
    skip==0 { print }
  ' "$file" >"$tmp"
  if cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
  else
    printf '⚙️  已从 %s 移除 llm-switch 配置片段\n' "$file"
    mv "$tmp" "$file"
  fi
}

remove_marked_block "$RC_ZSH" "$BEGIN_MARK" "$END_MARK"
remove_marked_block "$RC_BASH" "$BEGIN_MARK" "$END_MARK"

if [ -d "$INSTALL_ROOT" ]; then
  rm -rf "$INSTALL_ROOT"
  printf '🧹 已删除 llm-switch 安装目录：%s\n' "$INSTALL_ROOT"
else
  printf 'ℹ️  未发现 llm-switch 安装目录：%s\n' "$INSTALL_ROOT"
fi

printf '\nllm-switch 已卸载。若 shell 仍在运行，请执行：\n  exec "$SHELL" -l\n或手动 source 对应的 rc 文件以刷新环境。\n'
