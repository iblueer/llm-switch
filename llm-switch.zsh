#!/usr/bin/env zsh
# LLM 环境切换工具（Zsh）
# 环境目录默认位于 $HOME/.llm-switch/envs

: ${LLM_SWITCH_HOME:="$HOME/.llm-switch"}
typeset -g LLMS_ENV_DIR="$LLM_SWITCH_HOME/envs"
typeset -g LLMS_LAST="$LLMS_ENV_DIR/last_choice"
typeset -ga LLMS_REQUIRED_VARS=(LLM_PROVIDER LLM_API_KEY LLM_BASE_URL LLM_MODEL_NAME)
typeset -ga LLMS_SUBCOMMANDS=(help list ls use visionuse new edit del delete rm show current open dir)

_ls_info() { print -r -- "▸ $*"; }
_ls_warn() { print -r -- "⚠ $*"; }
_ls_err()  { print -r -- "✗ $*"; }
_ls_ok()   { print -r -- "✓ $*"; }

_ls_is_windows() {
  case "$OSTYPE" in
    cygwin*|msys*|win32*|mingw*) return 0 ;;
    *) return 1 ;;
  esac
}

_ls_with_spinner() {
  local msg="$1"; shift
  print -n -- "$msg "
  {
    local -a frames=('|' '/' '-' $'\\')
    local i=1
    while :; do
      printf "\r%s %s" "$msg" "${frames[i]}"
      i=$(( i % ${#frames} + 1 ))
      sleep 0.1
    done
  } &!
  local spid=$!
  "$@"
  local ret=$?
  kill $spid 2>/dev/null
  wait $spid 2>/dev/null || true
  printf "\r%s\n" "$msg"
  return $ret
}

_ls_ensure_envdir() { [[ -d "$LLMS_ENV_DIR" ]] || mkdir -p "$LLMS_ENV_DIR"; }

_ls_list_names() {
  _ls_ensure_envdir
  local file rel
  if command -v find >/dev/null 2>&1; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      rel="${file#$LLMS_ENV_DIR/}"
      rel="${rel%.env}"
      print -r -- "$rel"
    done < <(LC_ALL=C find "$LLMS_ENV_DIR" -type f -name '*.env' 2>/dev/null | LC_ALL=C sort)
  else
    local f
    for f in "$LLMS_ENV_DIR"/*.env(N); do
      rel="${f#$LLMS_ENV_DIR/}"
      rel="${rel%.env}"
      print -r -- "$rel"
    done
  fi
}

_llm_switch_env_candidates() {
  local cur="${1:-}"
  local prefix suffix search_dir entry base rel
  reply=()
  if [[ "$cur" == */* ]]; then
    prefix="${cur%/*}"
    suffix="${cur##*/}"
    search_dir="$LLMS_ENV_DIR/$prefix"
  else
    prefix=""
    suffix="$cur"
    search_dir="$LLMS_ENV_DIR"
  fi
  [[ -d "$search_dir" ]] || return
  local -a entries=()
  if command -v find >/dev/null 2>&1; then
    while IFS= read -r entry; do
      base="${entry##*/}"
      [[ "$base" == "$suffix"* ]] || continue
      if [[ -d "$entry" ]]; then
        rel="${prefix:+$prefix/}$base/"
        entries+=("$rel")
      elif [[ "$entry" == *.env ]]; then
        rel="${prefix:+$prefix/}${base%.env}"
        entries+=("$rel")
      fi
    done < <(LC_ALL=C find "$search_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type f -name '*.env' \) -print 2>/dev/null | LC_ALL=C sort)
  else
    for entry in "$search_dir"/*; do
      [[ -e "$entry" ]] || continue
      base="${entry##*/}"
      [[ "$base" == "$suffix"* ]] || continue
      if [[ -d "$entry" ]]; then
        rel="${prefix:+$prefix/}$base/"
        entries+=("$rel")
      elif [[ "$entry" == *.env ]]; then
        rel="${prefix:+$prefix/}${base%.env}"
        entries+=("$rel")
      fi
    done
  fi
  (( ${#entries[@]} > 0 )) && reply=(${(ou)entries})
}

_ls_open_path() {
  local file_path="$1"
  if _ls_is_windows; then
    local winpath="$file_path"
    if command -v cygpath >/dev/null 2>&1; then
      winpath="$(cygpath -w "$file_path")"
    fi
    if [[ -d "$file_path" ]]; then
      if command -v code >/dev/null 2>&1; then code -w "$winpath" && return 0; fi
      if command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$winpath" && return 0; fi
    else
      if command -v code >/dev/null 2>&1; then code -w "$winpath" && return 0; fi
      if command -v notepad.exe >/dev/null 2>&1; then notepad.exe "$winpath" && return 0; fi
    fi
    if command -v cmd.exe >/dev/null 2>&1; then
      cmd.exe /c start "" "$winpath" >/dev/null 2>&1 && return 0
    fi
    _ls_warn "请手动打开：$file_path"
    return 0
  fi
  if [[ -n "${LLM_SWITCH_EDITOR_CMD:-}" ]]; then
    if eval "$LLM_SWITCH_EDITOR_CMD ${(q)file_path}"; then
      return 0
    else
      _ls_warn "自定义编辑器命令失败：$LLM_SWITCH_EDITOR_CMD"
    fi
  fi
  if [[ -d "$file_path" ]]; then
    if command -v code >/dev/null 2>&1; then code -w "$file_path" && return 0; fi
    if command -v code-insiders >/dev/null 2>&1; then code-insiders -w "$file_path" && return 0; fi
    if command -v subl >/dev/null 2>&1; then subl -w "$file_path" && return 0; fi
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "$file_path" && return 0; fi
    if [[ -n "${VISUAL:-}" ]]; then
      local -a _ls_cmd
      _ls_cmd=("${(z)VISUAL}")
      "${_ls_cmd[@]}" "$file_path" && return 0
    fi
    if [[ -n "${EDITOR:-}" ]]; then
      local -a _ls_cmd
      _ls_cmd=("${(z)EDITOR}")
      "${_ls_cmd[@]}" "$file_path" && return 0
    fi
    if command -v vim >/dev/null 2>&1; then vim "$file_path" && return 0; fi
    if command -v nvim >/dev/null 2>&1; then nvim "$file_path" && return 0; fi
    _ls_warn "请手动打开：$file_path"
    return 0
  fi
  if [[ -n "${VISUAL:-}" ]]; then
    local -a _ls_cmd
    _ls_cmd=("${(z)VISUAL}")
    "${_ls_cmd[@]}" "$file_path" && return 0
  fi
  if [[ -n "${EDITOR:-}" ]]; then
    local -a _ls_cmd
    _ls_cmd=("${(z)EDITOR}")
    "${_ls_cmd[@]}" "$file_path" && return 0
  fi
  if command -v code >/dev/null 2>&1; then code -w "$file_path" && return 0; fi
  if command -v code-insiders >/dev/null 2>&1; then code-insiders -w "$file_path" && return 0; fi
  if command -v gedit >/dev/null 2>&1; then gedit --wait "$file_path" && return 0; fi
  if command -v vim >/dev/null 2>&1; then vim "$file_path" && return 0; fi
  if command -v nvim >/dev/null 2>&1; then nvim "$file_path" && return 0; fi
  if command -v nano >/dev/null 2>&1; then nano "$file_path" && return 0; fi
  if command -v subl >/dev/null 2>&1; then subl -w "$file_path" && return 0; fi
  if command -v open >/dev/null 2>&1; then open "$file_path" && return 0; fi
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$file_path" && return 0; fi
  _ls_warn "请手动打开：$file_path"
}

_ls_validate_env() {
  local file="$1"
  local missing=()
  local var
  for var in "${LLMS_REQUIRED_VARS[@]}"; do
    if [[ -z ${(P)var:-} ]]; then
      missing+=("$var")
    fi
  done
  if (( ${#missing} > 0 )); then
    _ls_err "环境文件缺少变量：${(j:, :)missing}"
    _ls_warn "请编辑：$file"
    return 1
  fi
}

_ls_load_env() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    _ls_err "未找到环境文件：$file"
    return 1
  fi
  unset LLM_PROVIDER LLM_API_KEY LLM_BASE_URL LLM_MODEL_NAME
  set -a
  source "$file"
  set +a
  _ls_validate_env "$file" || return 1
}

_ls_show() {
  if [[ -f "$LLMS_LAST" ]]; then
    _ls_info "已记忆默认环境：$(<"$LLMS_LAST")"
  else
    _ls_info "暂无已记忆默认环境。"
  fi
  print -r -- "当前生效变量："
  printf '  %-18s = %s\n' LLM_PROVIDER "${LLM_PROVIDER:-<未设置>}"
  printf '  %-18s = %s\n' LLM_API_KEY "${LLM_API_KEY:+<已设置>}"
  printf '  %-18s = %s\n' LLM_BASE_URL "${LLM_BASE_URL:-<未设置>}"
  printf '  %-18s = %s\n' LLM_MODEL_NAME "${LLM_MODEL_NAME:-<未设置>}"

  if [[ -n "${LLM_VISION_API_KEY:-}" || -n "${LLM_VISION_MODEL_NAME:-}" ]]; then
    print -r -- "Vision 变量："
    printf '  %-18s = %s\n' LLM_VISION_API_KEY "${LLM_VISION_API_KEY:+<已设置>}"
    printf '  %-18s = %s\n' LLM_VISION_BASE_URL "${LLM_VISION_BASE_URL:-<未设置>}"
    printf '  %-18s = %s\n' LLM_VISION_MODEL_NAME "${LLM_VISION_MODEL_NAME:-<未设置>}"
  fi
}

_ls_cmd_list() {
  _ls_ensure_envdir
  local saved=""
  [[ -f "$LLMS_LAST" ]] && saved="$(<"$LLMS_LAST")"
  local names=()
  names=($(_ls_list_names))
  print -r -- "可用环境配置（$LLMS_ENV_DIR）："
  if (( ${#names} == 0 )); then
    print -r -- "  （空）可添加 *.env 文件"
    return 0
  fi
  local n
  for n in "${names[@]}"; do
    if [[ -n "$saved" && "$n" == "$saved" ]]; then
      print -r -- "  * $n  (默认)"
    else
      print -r -- "    $n"
    fi
  done
}

_ls_cmd_switch() {
  local name="$1"
  [[ -z "$name" ]] && { _ls_err "用法：llm-switch <name>"; return 2; }
  [[ "$name" == *.env ]] || name="$name.env"
  local file="$LLMS_ENV_DIR/$name"
  if _ls_with_spinner "加载环境..." _ls_load_env "$file"; then
    print -r -- "${name%.env}" > "$LLMS_LAST"
    _ls_ok "已切换到环境：${name%.env}（已保存为默认）"
    _ls_show
  else
    return 1
  fi
}

_ls_cmd_vision_use() {
  local name="$1"
  [[ -z "$name" ]] && { _ls_err "用法：llm-switch visionuse <name>"; return 2; }
  [[ "$name" == *.env ]] || name="$name.env"
  local file="$LLMS_ENV_DIR/$name"
  if [[ ! -f "$file" ]]; then
    _ls_err "未找到环境文件：$file"
    return 1
  fi

  local vars_output
  vars_output=$(
    unset LLM_API_KEY LLM_BASE_URL LLM_MODEL_NAME LLM_VISION_API_KEY LLM_VISION_BASE_URL LLM_VISION_MODEL_NAME
    source "$file" >/dev/null 2>&1
    # 优先使用 Vision 专属变量，否则使用通用变量回退
    V_KEY="${LLM_VISION_API_KEY:-$LLM_API_KEY}"
    V_URL="${LLM_VISION_BASE_URL:-$LLM_BASE_URL}"
    V_MODEL="${LLM_VISION_MODEL_NAME:-$LLM_MODEL_NAME}"
    printf "%s\n%s\n%s" "$V_KEY" "$V_URL" "$V_MODEL"
  )

  local -a lines
  lines=("${(f)vars_output}")

  if [[ ${#lines} -lt 3 ]]; then
      _ls_err "无法从 $name 加载 vision 变量（或变量为空）"
      return 1
  fi

  export LLM_VISION_API_KEY="${lines[1]}"
  export LLM_VISION_BASE_URL="${lines[2]}"
  export LLM_VISION_MODEL_NAME="${lines[3]}"
  export LLM_VISION_MODEL="${lines[3]}"

  _ls_ok "已设置 Vision 变量为环境：${name%.env}"
  _ls_show
}

_ls_template() {
  cat <<'T'
# 示例模板：请按需修改
export LLM_PROVIDER=""
export LLM_API_KEY=""
export LLM_BASE_URL=""
export LLM_MODEL_NAME=""
T
}

_ls_cmd_new() {
  local name="$1"
  [[ -z "$name" ]] && { _ls_err "用法：llm-switch new <name>"; return 2; }
  _ls_ensure_envdir
  [[ "$name" == *.env ]] || name="$name.env"
  local file="$LLMS_ENV_DIR/$name"
  if [[ -f "$file" ]]; then
    _ls_err "已存在：$file"
    return 1
  fi
  _ls_template > "$file"
  _ls_ok "已创建：$file"
  _ls_open_path "$file"
}

_ls_cmd_edit() {
  local name="$1"
  [[ -z "$name" ]] && { _ls_err "用法：llm-switch edit <name>"; return 2; }
  _ls_ensure_envdir
  [[ "$name" == *.env ]] || name="$name.env"
  local file="$LLMS_ENV_DIR/$name"
  if [[ ! -f "$file" ]]; then
    _ls_template > "$file"
    _ls_info "不存在，已创建模板：$file"
  fi
  _ls_open_path "$file"
}

_ls_cmd_del() {
  local name="$1"
  [[ -z "$name" ]] && { _ls_err "用法：llm-switch del <name>"; return 2; }
  _ls_ensure_envdir
  [[ "$name" == *.env ]] || name="$name.env"
  local file="$LLMS_ENV_DIR/$name"
  if [[ ! -f "$file" ]]; then
    _ls_err "未找到：$file"
    return 1
  fi
  print -n -- "确认删除 ${name%.env} ? 输入 yes 以继续："
  local answer; read -r answer
  if [[ "$answer" == yes ]]; then
    rm -f -- "$file"
    _ls_ok "已删除：$file"
    if [[ -f "$LLMS_LAST" && "$(<"$LLMS_LAST")" == "${name%.env}" ]]; then
      rm -f -- "$LLMS_LAST"
      _ls_info "已清理默认记忆。"
    fi
  else
    _ls_info "已取消。"
  fi
}

_llm_switch_zsh_complete() {
  local cur="${words[CURRENT]}"
  local -a envs
  _llm_switch_env_candidates "$cur"
  envs=("${reply[@]}")
  if (( CURRENT == 2 )); then
    if [[ "$cur" != */* ]]; then
      (( ${#LLMS_SUBCOMMANDS[@]} > 0 )) && compadd -a LLMS_SUBCOMMANDS
    fi
    (( ${#envs[@]} > 0 )) && compadd -Q -S '' -a envs
    return
  fi
  case "${words[2]}" in
    use|visionuse|new|edit|del|delete|rm)
      (( ${#envs[@]} > 0 )) && compadd -Q -S '' -a envs
      ;;
  esac
}

_ls_help() {
  cat <<H
用法：
  llm-switch list                 列出全部环境
  llm-switch use <name>           切换到 <name> 环境（无需 .env 后缀）
  llm-switch visionuse <name>     切换 Vision 变量到 <name> 环境
  llm-switch new <name>           新建 <name>.env，并打开编辑器
  llm-switch edit <name>          编辑 <name>.env（不存在则创建模板）
  llm-switch del <name>           删除 <name>.env（需输入 yes 确认）
  llm-switch show|current         显示已记忆的默认与当前变量
  llm-switch open|dir             打开环境目录
  llm-switch help                 显示本帮助

目录：
  环境目录：$LLMS_ENV_DIR
  记忆文件：$LLMS_LAST

配置：
  LLM_SWITCH_HOME        默认 $HOME/.llm-switch
  LLM_SWITCH_EDITOR_CMD  自定义编辑命令（优先级最高）
H
}

llm-switch() {
  local cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    ""|help|-h|--help) _ls_help ;;
    list|ls)            _ls_cmd_list ;;
    use)                _ls_cmd_switch "$1" ;;
    visionuse)          _ls_cmd_vision_use "$1" ;;
    new)                _ls_cmd_new "$@" ;;
    edit)               _ls_cmd_edit "$@" ;;
    del|delete|rm)      _ls_cmd_del "$@" ;;
    show|current)       _ls_show ;;
    open|dir)           _ls_open_path "$LLMS_ENV_DIR" ;;
    *)                  _ls_err "未知命令：$cmd"; _ls_info "请使用 'llm-switch use <name>' 切换环境，或运行 'llm-switch help' 查看帮助"; return 2 ;;
  esac
}

_ls_setup_completion() {
  if (( $+functions[compdef] )); then
    compdef _llm_switch_zsh_complete llm-switch
  fi
}

_ls_autoload_on_startup() {
  _ls_ensure_envdir
  local chosen=""
  if [[ -f "$LLMS_LAST" ]]; then
    chosen="$(<"$LLMS_LAST")"
  else
    local names=($(_ls_list_names))
    if (( ${#names} > 0 )); then
      chosen="${names[1]}"
    fi
  fi
  if [[ -n "$chosen" ]]; then
    _ls_cmd_switch "$chosen" >/dev/null 2>&1 || true
  fi
}

if [[ -o interactive ]]; then
  _ls_setup_completion
  _ls_autoload_on_startup
fi
