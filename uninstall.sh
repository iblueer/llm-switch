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

# 尝试移除用户目录中的包装可执行文件（仅当指向/引用安装目录时）
for _cand in "$HOME/.local/bin/llm-switch" "$HOME/bin/llm-switch"; do
  if [ -L "$_cand" ]; then
    _target="$(readlink "$_cand" 2>/dev/null || true)"
    case "$_target" in
      "$INSTALL_ROOT"/*)
        rm -f -- "$_cand" && printf '🧹 已删除包装脚本：%s -> %s\n' "$_cand" "$_target"
        ;;
    esac
  elif [ -f "$_cand" ]; then
    if grep -F -q "$INSTALL_ROOT/bin/llm-switch" "$_cand" 2>/dev/null \
       || grep -F -q "$HOME/.llm-switch/bin" "$_cand" 2>/dev/null \
       || grep -F -q '\\$HOME/.llm-switch/bin' "$_cand" 2>/dev/null; then
      rm -f -- "$_cand" && printf '🧹 已删除包装脚本：%s\n' "$_cand"
    fi
  fi
done

# 在 PATH 中扫描所有名为 llm-switch 的可执行，若为包装器/指向安装目录则删除
IFS=":" read -r -a _path_dirs <<< "${PATH:-}"
for _dir in "${_path_dirs[@]}"; do
  [ -n "$_dir" ] || continue
  _cand="$_dir/llm-switch"
  [ -e "$_cand" ] || continue
  # 仅对可写目标进行处理，避免误删系统文件
  [ -w "$_cand" ] || continue
  if [ -L "$_cand" ]; then
    _target="$(readlink "$_cand" 2>/dev/null || true)"
    case "$_target" in
      "$INSTALL_ROOT"/*|*/.llm-switch/bin/*)
        rm -f -- "$_cand" && printf '🧹 已删除 PATH 中的包装脚本：%s -> %s\n' "$_cand" "$_target"
        ;;
    esac
  elif [ -f "$_cand" ]; then
    if grep -F -q "/.llm-switch/bin/llm-switch" "$_cand" 2>/dev/null \
       || grep -F -q "llm-switch 包装脚本" "$_cand" 2>/dev/null ; then
      rm -f -- "$_cand" && printf '🧹 已删除 PATH 中的包装脚本：%s\n' "$_cand"
    fi
  fi
done

printf '\nllm-switch 已卸载。若 shell 仍在运行，请执行：\n  exec "$SHELL" -l\n或手动 source 对应的 rc 文件以刷新环境。\n'

# 额外处理：尝试从当前 Shell 会话中移除命令/补全（若脚本被 source 执行时可生效）

# 检测是否被 source 执行：
is_sourced=0
if [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then
  case $ZSH_EVAL_CONTEXT in
    *:file) is_sourced=1 ;;
  esac
elif [ -n "${BASH_SOURCE:-}" ]; then
  if [ "${BASH_SOURCE[0]-}" != "$0" ]; then
    is_sourced=1
  fi
fi

remove_from_current_session() {
  # 移除函数定义
  if [ -n "${BASH_VERSION:-}" ]; then
    if declare -F llm-switch >/dev/null 2>&1; then
      unset -f llm-switch 2>/dev/null || true
    fi
    # 移除 bash 补全
    if type complete >/dev/null 2>&1; then
      complete -r llm-switch 2>/dev/null || true
    fi
  fi

  if [ -n "${ZSH_VERSION:-}" ]; then
    if typeset -f llm-switch >/dev/null 2>&1 || typeset -f -- llm-switch >/dev/null 2>&1; then
      unfunction llm-switch 2>/dev/null || true
    fi
    # 移除 zsh 补全
    if typeset -f compdef >/dev/null 2>&1; then
      compdef -d llm-switch 2>/dev/null || true
    fi
  fi

  # 移除可能的 alias
  if alias llm-switch >/dev/null 2>&1; then
    unalias llm-switch 2>/dev/null || true
  fi

  # 清理命令哈希表，避免旧路径缓存
  hash -r 2>/dev/null || true

  # 取消导出的相关变量（仅当前会话有效）
  unset LLM_PROVIDER LLM_API_KEY LLM_BASE_URL LLM_MODEL_NAME 2>/dev/null || true
  unset LLM_SWITCH_HOME LLMS_ENV_DIR LLMS_LAST LLMS_REQUIRED_VARS LLMS_SUBCOMMANDS 2>/dev/null || true
}

if [ "$is_sourced" = "1" ] || [ "${LLM_SWITCH_FORCE_UNLOAD:-0}" = "1" ]; then
  remove_from_current_session
  printf '\n已从当前会话移除 llm-switch 命令与补全。\n'
else
  printf '\n提示：当前 shell 会话中若仍能调用 llm-switch，这是因为函数仍在内存中。\n' >&2
  printf '如需立即清除，请在当前 shell 执行： source "%s"\n' "$0" >&2
  printf '或运行： exec "$SHELL" -l 以重启登录会话。\n' >&2
fi
