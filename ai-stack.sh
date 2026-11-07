#!/bin/bash
#
# ai-stack.sh — macOS 一键安装 / 更新 AI 工具栈
#
# 特点：
#   * 不需要预先安装 Homebrew，首次运行会自动装好
#   * 已安装的自动升级，未安装的自动安装，可重复运行
#   * 所有 GUI 应用和 CLI 都通过 Homebrew Cask / Formula 管理
#   * 兼容 macOS 自带的 Bash 3.2
#
# 常用命令：
#   ./ai-stack.sh                  # 安装/更新全部（含推荐补充）
#   ./ai-stack.sh --no-recommend   # 只装清单里的，不装推荐补充
#   ./ai-stack.sh --only codex,claude-code
#   ./ai-stack.sh --skip trae-cn,antigravity-ide
#   ./ai-stack.sh --dry-run        # 只预览，不改系统
#   ./ai-stack.sh --list           # 查看所有条目
#
# 国内网络：
#   ./ai-stack.sh --cn             # Homebrew 使用清华镜像
#   ./ai-stack.sh --proxy http://127.0.0.1:7890
#
set -o pipefail

SCRIPT_VERSION="1.4.1"

# ---------------------------------------------------------------------------
# 默认参数
# ---------------------------------------------------------------------------
DRY_RUN=0
LIST_ONLY=0
STATUS_ONLY=0
NO_UPDATE=0
NO_GREEDY=0
NO_RECOMMEND=0
NO_CLAUDE=0
DO_CLEANUP=0
USE_CN=0
ADOPT=0
PROXY=""
ONLY=""
SKIP=""
BREW=""
BREW_BIN=""
LOG_DIR=""
LOG_FILE=""
FAILED=0
START_TS=$(date +%s)

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# ---------------------------------------------------------------------------
# 输出函数
# ---------------------------------------------------------------------------
info()  { printf '  %s\n' "$*"; }
ok()    { printf '  %s%s%s %s\n' "$C_GREEN" "✓" "$C_RESET" "$*"; }
warn()  { printf '  %s%s%s %s\n' "$C_YELLOW" "!" "$C_RESET" "$*"; }
err()   { printf '  %s%s%s %s\n' "$C_RED" "✗" "$C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }

section() {
  printf '\n%s%s━━ %s ━━%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET"
}

usage() {
  cat <<'EOF'
AI 工具栈 · macOS 一键安装 / 更新

用法：
  ./ai-stack.sh [选项]

选项：
  --only LIST        只处理指定条目/分组，逗号分隔
                     例：--only codex,claude-code,apps
  --skip LIST        跳过指定条目/分组，逗号分隔
                     例：--skip qoder,antigravity-ide
  --no-recommend     不安装“推荐补充”分组
  --no-claude        跳过 Claude 桌面版和 Claude Code（网络受限时用）
  --adopt            接管 /Applications 里手动安装的同名 App，交给 Homebrew 管理
  --no-adopt         只检测手动安装的 App 并跳过，不接管（默认）
  --dry-run, -n      只预览，不修改系统
  --list, -l         列出全部条目后退出
  --status           以 JSON 输出所有工具的安装状态（给脚本/AI 读取）
  --no-update        不执行 brew update（更快，但可能不是最新）
  --no-greedy        不强制升级自带自动更新的 App（更快）
  --cleanup          结束后执行 brew cleanup --prune=7
  --cn               Homebrew 使用清华镜像（国内网络）
  --proxy URL        为本次安装设置 HTTP/HTTPS 代理
  --help, -h         显示本帮助
  --version          显示脚本版本

分组：
  base       基础工具链（node / git / gh / uv / ripgrep 等）
  apps       你点名的桌面应用
  cli        你点名的命令行工具
  recommend  推荐的 AI 常用必备工具（默认安装）

示例：
  ./ai-stack.sh
  ./ai-stack.sh --no-recommend
  ./ai-stack.sh --only chatgpt,codex --proxy http://127.0.0.1:7890
  ./ai-stack.sh --no-claude
  ./ai-stack.sh --adopt --only chatgpt,zed
  ./ai-stack.sh --skip trae-cn,workbuddy-cn
  ./ai-stack.sh --dry-run --only recommend

日志：
  ~/Library/Logs/ai-stack/run-*.log
EOF
}

# ---------------------------------------------------------------------------
# 清单
#
# add_item 分组 键名 显示名 类型 标识 备注
#   类型：cask | formula | npm
#   标识：Homebrew cask token / formula 名 / npm 包名
#
# 想增删工具，直接改这一段即可。
# ---------------------------------------------------------------------------
ITEM_GROUP=()
ITEM_KEY=()
ITEM_LABEL=()
ITEM_TYPE=()
ITEM_ID=()
ITEM_NOTE=()
ITEM_FALLBACK=()

add_item() {
  ITEM_GROUP+=("$1")
  ITEM_KEY+=("$2")
  ITEM_LABEL+=("$3")
  ITEM_TYPE+=("$4")
  ITEM_ID+=("$5")
  ITEM_NOTE+=("${6:-}")
  ITEM_FALLBACK+=("${7:-}")
}

# ---- 基础工具链 -----------------------------------------------------------
add_item base node     "Node.js（npm / npx）"              formula node
add_item base git      "Git"                               formula git
add_item base gh       "GitHub CLI（gh）"                  formula gh
add_item base uv       "uv / uvx（Python 工具链）"         formula uv
add_item base bun      "Bun（JS 运行时 / bunx）"           formula bun
add_item base jq       "jq（JSON 处理）"                   formula jq
add_item base ripgrep  "ripgrep（rg，代码搜索）"           formula ripgrep
add_item base fd       "fd（快速文件查找）"                formula fd

# ---- 你点名的桌面应用 -----------------------------------------------------
add_item apps chatgpt          "ChatGPT 桌面版"                       cask chatgpt
add_item apps claude           "Claude 桌面版"                        cask claude           "若 downloads.claude.ai 超时：可开 --proxy，或用 App Store 版"
add_item apps antigravity      "Google Antigravity 2（Agent 调度台）"  cask antigravity
add_item apps antigravity-ide  "Google Antigravity IDE"               cask antigravity-ide
add_item apps workbuddy-cn     "WorkBuddy（国内版）"                   cask workbuddy-cn    "国际版可改用 workbuddy-ai"
add_item apps trae-cn          "Trae CN（国内版）"                     cask trae-cn          "国际版可改用 trae"
add_item apps qoder            "Qoder（国际版）"                       cask qoder            "国内版 Qoder CN 请用应用内更新，或 --skip qoder"
add_item apps doubao           "豆包"                                  cask doubao
add_item apps clash-verge-rev  "Clash Verge Rev"                      cask clash-verge-rev
add_item apps cc-switch        "CC Switch（Claude/Codex 配置切换）"     cask cc-switch
add_item apps feishu           "飞书"                                  cask feishu
add_item apps google-chrome    "Google Chrome"                        cask google-chrome
add_item apps cherry-studio    "Cherry Studio"                        cask cherry-studio
add_item apps deepseek-harness "DeepSeek Harness 桌面版"               cask deepseek-harness
add_item apps github           "GitHub Desktop"                       cask github
add_item apps hermes-desktop   "Hermes Agent 桌面版"                   cask hermes-desktop
add_item apps google-gemini    "Google Gemini 客户端"                  cask google-gemini
add_item apps grok-bot         "Grok Bot 客户端"                       cask grok-bot
add_item apps opencode-desktop "OpenCode 客户端"                       cask opencode-desktop

# ---- 你点名的命令行工具 ---------------------------------------------------
add_item cli codex            "Codex CLI（codex）"                     cask codex
add_item cli claude-code      "Claude Code CLI（claude）"              cask claude-code      "" npm:@anthropic-ai/claude-code
add_item cli grok             "Grok CLI（grok）"                       cask grok-build       "xAI 官方 Grok Build"
add_item cli agy              "Antigravity CLI（agy）"                 cask antigravity-cli
add_item cli qwen             "Qwen Code CLI（qwen）"                  formula qwen-code
add_item cli hermes-cli       "Hermes Agent CLI（hermes）"             formula hermes-agent

# ---- 推荐补充：AI 常用必备 ------------------------------------------------
add_item recommend gemini-cli          "Gemini CLI（gemini）"                  formula gemini-cli
add_item recommend copilot-cli         "GitHub Copilot CLI（copilot）"          cask copilot-cli
add_item recommend opencode            "OpenCode（opencode）"                   formula opencode
add_item recommend aider               "Aider（aider）"                         formula aider
add_item recommend cursor-cli          "Cursor CLI（cursor-agent）"             cask cursor-cli
add_item recommend kiro-cli            "Kiro CLI（kiro-cli）"                   cask kiro-cli
add_item recommend ollama-app          "Ollama（本地大模型）"                   cask ollama-app
add_item recommend lm-studio           "LM Studio（本地大模型）"                cask lm-studio
add_item recommend cursor              "Cursor（AI IDE）"                       cask cursor
add_item recommend visual-studio-code  "VS Code"                               cask visual-studio-code
add_item recommend zed                 "Zed（高性能编辑器）"                    cask zed
add_item recommend ghostty             "Ghostty（终端）"                        cask ghostty
add_item recommend orbstack            "OrbStack（Docker 替代）"               cask orbstack
add_item recommend chatbox             "Chatbox（多模型聊天客户端）"           cask chatbox

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
need_value() {
  [[ $# -ge 2 && -n "$2" ]] || die "参数 $1 需要一个值"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      need_value "$@"; ONLY="$2"; shift 2 ;;
    --only=*)
      ONLY="${1#*=}"; shift ;;
    --skip)
      need_value "$@"; SKIP="$2"; shift 2 ;;
    --skip=*)
      SKIP="${1#*=}"; shift ;;
    --no-recommend) NO_RECOMMEND=1; shift ;;
    --recommend)    NO_RECOMMEND=0; shift ;;
    --no-claude)    NO_CLAUDE=1; shift ;;
    --claude)       NO_CLAUDE=0; shift ;;
    --adopt)        ADOPT=1; shift ;;
    --no-adopt)     ADOPT=0; shift ;;
    --dry-run|-n)   DRY_RUN=1; shift ;;
    --list|-l)      LIST_ONLY=1; shift ;;
    --status)       STATUS_ONLY=1; shift ;;
    --no-update)    NO_UPDATE=1; shift ;;
    --no-greedy)    NO_GREEDY=1; shift ;;
    --cleanup)      DO_CLEANUP=1; shift ;;
    --cn)           USE_CN=1; shift ;;
    --proxy)
      need_value "$@"; PROXY="$2"; shift 2 ;;
    --proxy=*)
      PROXY="${1#*=}"; shift ;;
    --help|-h)      usage; exit 0 ;;
    --version)      printf 'ai-stack.sh %s\n' "$SCRIPT_VERSION"; exit 0 ;;
    *)
      err "未知参数：$1"
      printf '\n'
      usage
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 选择逻辑
# ---------------------------------------------------------------------------
list_has() {
  local needle="$1" list="$2" item
  local IFS=', '
  [[ -z "$list" ]] && return 1
  for item in $list; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

is_selected() {
  local key="$1" group="$2"

  if [[ -n "$ONLY" ]]; then
    list_has "$key" "$ONLY" || list_has "$group" "$ONLY" || return 1
  fi

  if [[ -n "$SKIP" ]]; then
    list_has "$key" "$SKIP" && return 1
    list_has "$group" "$SKIP" && return 1
  fi

  if [[ "$NO_CLAUDE" -eq 1 ]]; then
    case "$key" in
      claude|claude-code) return 1 ;;
    esac
  fi

  if [[ "$group" == "recommend" && "$NO_RECOMMEND" -eq 1 ]]; then
    return 1
  fi

  return 0
}

group_title() {
  case "$1" in
    base)      printf '基础工具链' ;;
    apps)      printf '桌面应用（你点名的）' ;;
    cli)       printf '命令行工具（你点名的）' ;;
    recommend) printf '推荐补充：AI 常用必备' ;;
    *)         printf '%s' "$1" ;;
  esac
}

validate_selection() {
  local token found i
  for token in ${ONLY//,/ } ${SKIP//,/ }; do
    [[ -z "$token" ]] && continue
    found=0
    for i in "${!ITEM_KEY[@]}"; do
      if [[ "$token" == "${ITEM_KEY[$i]}" || "$token" == "${ITEM_GROUP[$i]}" ]]; then
        found=1
        break
      fi
    done
    [[ "$found" -eq 0 ]] && warn "未知条目或分组：$token"
  done
}

count_selected() {
  local i n=0
  for i in "${!ITEM_KEY[@]}"; do
    if is_selected "${ITEM_KEY[$i]}" "${ITEM_GROUP[$i]}"; then
      n=$((n + 1))
    fi
  done
  printf '%s' "$n"
}

show_list() {
  printf '%s%sAI 工具栈清单（共 %d 项）%s\n\n' "$C_BOLD" "$C_CYAN" "${#ITEM_KEY[@]}" "$C_RESET"
  printf '%-22s %-10s %-9s %s\n' "KEY" "GROUP" "TYPE" "名称"
  printf '%s\n' "------------------------------------------------------------------------------------------"
  local i
  for i in "${!ITEM_KEY[@]}"; do
    printf '%-22s %-10s %-9s %s\n' \
      "${ITEM_KEY[$i]}" "${ITEM_GROUP[$i]}" "${ITEM_TYPE[$i]}" "${ITEM_LABEL[$i]}"
    if [[ -n "${ITEM_NOTE[$i]}" ]]; then
      printf '%-22s %-10s %-9s %s%s%s\n' "" "" "" "$C_DIM" "${ITEM_NOTE[$i]}" "$C_RESET"
    fi
    if [[ -n "${ITEM_FALLBACK[$i]}" ]]; then
      printf '%-22s %-10s %-9s %s备用：%s%s\n' "" "" "" "$C_DIM" "${ITEM_FALLBACK[$i]}" "$C_RESET"
    fi
  done
  printf '\n说明：全部通过 Homebrew 安装/升级；不需要预先安装 Homebrew。\n'
  printf '      默认包含 recommend 分组；只要点名清单请加 --no-recommend。\n'
}

# ---------------------------------------------------------------------------
# 日志
# ---------------------------------------------------------------------------
init_log() {
  LOG_DIR="$HOME/Library/Logs/ai-stack"
  if mkdir -p "$LOG_DIR" 2>/dev/null; then
    LOG_FILE="$LOG_DIR/run-$(date '+%Y%m%d-%H%M%S').log"
    : > "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    ln -sf "$LOG_FILE" "$LOG_DIR/latest.log" 2>/dev/null || true
  else
    warn "无法创建日志目录，本次只输出到终端。"
  fi
}

# ---------------------------------------------------------------------------
# Homebrew 安装 / 环境准备
# ---------------------------------------------------------------------------
find_brew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW_BIN="/usr/local/bin/brew"
  elif command -v brew >/dev/null 2>&1; then
    BREW_BIN="$(command -v brew)"
  else
    BREW_BIN=""
  fi
}

add_brew_to_profile() {
  local profile="$HOME/.zprofile"
  local marker="# >>> ai-stack: Homebrew >>>"
  local line

  if [[ -f "$profile" ]] && grep -Fq "$marker" "$profile" 2>/dev/null; then
    return 0
  fi
  if [[ -f "$profile" ]] && grep -Fq 'brew shellenv' "$profile" 2>/dev/null; then
    return 0
  fi

  line="eval \"\$($BREW_BIN shellenv)\""
  {
    printf '\n%s\n' "$marker"
    printf '%s\n' "$line"
    printf '%s\n' "# <<< ai-stack: Homebrew <<<"
  } >> "$profile" 2>/dev/null || {
    warn "无法写入 ~/.zprofile，请手动把下面一行加入 shell 配置："
    warn "$line"
    return 0
  }
  info "已把 Homebrew 环境写入 ~/.zprofile（新开的终端生效）。"
}

ensure_brew() {
  local had_brew_in_path=0
  command -v brew >/dev/null 2>&1 && had_brew_in_path=1

  find_brew

  if [[ -n "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
    BREW="$BREW_BIN"
    # brew 已安装但当前 PATH 里没有：补一次 shell 配置（dry-run 不写文件）
    if [[ "$had_brew_in_path" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
      add_brew_to_profile
    fi
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "未检测到 Homebrew；实际运行时将先自动安装 Homebrew。"
    return 0
  fi

  section "安装 Homebrew"

  if ! xcode-select -p >/dev/null 2>&1; then
    warn "缺少 Xcode Command Line Tools，正在打开安装窗口…"
    xcode-select --install >/dev/null 2>&1 || true
    die "请完成 Command Line Tools 安装后，重新运行本脚本。"
  fi

  info "未检测到 Homebrew，开始官方安装脚本（可能需要输入管理员密码）…"

  if [[ "$USE_CN" -eq 1 ]]; then
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
    export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  fi

  local installer_url="${AI_STACK_BREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"
  local install_script
  install_script="$(curl -fsSL --retry 3 --connect-timeout 20 "$installer_url")" || {
    err "无法下载 Homebrew 安装脚本，请检查网络/代理。"
    exit 1
  }

  # 终端里让官方脚本正常提示（回车确认 + 管理员密码）；
  # 非交互场景先缓存 sudo，使用 NONINTERACTIVE 避免卡住。
  if [[ -t 0 ]]; then
    /bin/bash -c "$install_script" || {
      err "Homebrew 安装失败。"
      err "可手动安装后重试："
      err '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      exit 1
    }
  else
    if ! /usr/bin/sudo -v; then
      err "当前不是交互式终端，无法输入管理员密码。"
      err "请先把脚本下载到本地再运行，例如："
      err "  curl -fsSL <脚本地址> -o ~/ai-stack.sh && bash ~/ai-stack.sh"
      exit 1
    fi
    NONINTERACTIVE=1 /bin/bash -c "$install_script" || {
      err "Homebrew 安装失败。"
      err "可手动安装后重试："
      err '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      exit 1
    }
  fi

  find_brew
  [[ -n "$BREW_BIN" ]] || die "Homebrew 安装完成但未找到 brew，请重开终端后重试。"
  eval "$("$BREW_BIN" shellenv)"
  BREW="$BREW_BIN"
  add_brew_to_profile
}

# ---------------------------------------------------------------------------
# 版本 / 更新状态
# ---------------------------------------------------------------------------
version_of() {
  local type="$1" id="$2"

  case "$type" in
    cask)
      "$BREW" list --cask --versions "$id" 2>/dev/null | awk 'NR==1 {print $2}'
      ;;
    formula)
      "$BREW" list --versions "$id" 2>/dev/null | awk 'NR==1 {print $2}'
      ;;
    npm)
      npm ls -g --depth=0 "$id" 2>/dev/null \
        | sed -n 's/.*@\([0-9][0-9A-Za-z.+-]*\).*/\1/p' \
        | head -1
      ;;
  esac
}

is_outdated_cask() {
  case " $OUTDATED_CASKS " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

is_outdated_formula() {
  case " $OUTDATED_FORMULAS " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# 应用清单检测（不依赖 Homebrew 的账本）
#   App 可能来自手动拖入、pkg、App Store —— brew 完全不知道它们存在。
# ---------------------------------------------------------------------------
app_name_for_key() {
  case "$1" in
    chatgpt)            printf 'ChatGPT.app' ;;
    claude)             printf 'Claude.app' ;;
    antigravity)        printf 'Antigravity.app' ;;
    antigravity-ide)    printf 'Antigravity IDE.app' ;;
    workbuddy-cn)       printf 'WorkBuddy.app' ;;
    trae-cn)            printf 'Trae CN.app' ;;
    qoder)              printf 'Qoder.app' ;;
    doubao)             printf 'Doubao.app' ;;
    clash-verge-rev)    printf 'Clash Verge.app' ;;
    cc-switch)          printf 'CC Switch.app' ;;
    feishu)             printf 'Feishu.app' ;;
    google-chrome)      printf 'Google Chrome.app' ;;
    cherry-studio)      printf 'Cherry Studio.app' ;;
    deepseek-harness)   printf 'DeepSeek Harness.app' ;;
    github)             printf 'GitHub Desktop.app' ;;
    hermes-desktop)     printf 'Hermes.app' ;;
    google-gemini)      printf 'Gemini.app' ;;
    grok-bot)           printf 'Grok Bot.app' ;;
    opencode-desktop)   printf 'OpenCode.app' ;;
    ollama-app)         printf 'Ollama.app' ;;
    lm-studio)          printf 'LM Studio.app' ;;
    cursor)             printf 'Cursor.app' ;;
    visual-studio-code) printf 'Visual Studio Code.app' ;;
    zed)                printf 'Zed.app' ;;
    ghostty)            printf 'Ghostty.app' ;;
    orbstack)           printf 'OrbStack.app' ;;
    chatbox)            printf 'Chatbox.app' ;;
    *)                  printf '' ;;
  esac
}

app_path_by_name() {
  local name="$1" d
  [[ -n "$name" ]] || return 1
  for d in "/Applications" "$HOME/Applications"; do
    [[ -d "$d/$name" ]] && { printf '%s' "$d/$name"; return 0; }
  done
  return 1
}

# 纯 CLI 的 cask 条目：没有 .app，只能靠命令名判断是否已存在
cli_bin_for_key() {
  case "$1" in
    codex)       printf 'codex' ;;
    claude-code) printf 'claude' ;;
    grok)        printf 'grok' ;;
    agy)         printf 'agy' ;;
    copilot-cli) printf 'copilot' ;;
    cursor-cli)  printf 'cursor-agent' ;;
    kiro-cli)    printf 'kiro-cli' ;;
    *)           printf '' ;;
  esac
}

app_version_of_path() {
  local plist="$1/Contents/Info.plist"
  [[ -f "$plist" ]] || return 0
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null \
    || defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null \
    || true
}

cask_latest_version() {
  [[ -n "$BREW" ]] || return 0
  "$BREW" info --cask --json=v2 "$1" 2>/dev/null \
    | plutil -extract casks.0.version raw -o - - 2>/dev/null \
    | head -1
}

# ---------------------------------------------------------------------------
# 单项处理
# ---------------------------------------------------------------------------
process_cask() {
  local token="$1"
  local app_name="${2:-}"
  local greedy_arg="--greedy"
  local existing="" app_ver="" cask_ver=""
  [[ "$NO_GREEDY" -eq 1 ]] && greedy_arg=""

  if "$BREW" list --cask "$token" >/dev/null 2>&1; then
    # brew 认为装了，但 App 文件被手动删掉 → 补装回来
    if [[ -n "$app_name" ]] && ! app_path_by_name "$app_name" >/dev/null 2>&1; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        info "App 文件缺失，将重装：brew install --cask --force $token"
        RESULT_STATUS="dry"
      else
        info "App 文件缺失，重装 $token …"
        if "$BREW" install --cask --force "$token"; then
          RESULT_STATUS="installed"
        else
          RESULT_STATUS="failed"
          return 1
        fi
      fi
      return 0
    fi

    if is_outdated_cask "$token"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        info "将升级：brew upgrade --cask $greedy_arg $token"
        RESULT_STATUS="dry"
      else
        info "升级 $token …"
        if "$BREW" upgrade --cask $greedy_arg "$token" \
           || "$BREW" upgrade --cask $greedy_arg --force "$token"; then
          RESULT_STATUS="updated"
        else
          RESULT_STATUS="failed"
          return 1
        fi
      fi
    else
      RESULT_STATUS="current"
    fi
    return 0
  fi

  # ---- 以下：brew 账本里没有，先看 /Applications 里有没有手动安装的同名 App ----
  existing="$(app_path_by_name "$app_name" 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    app_ver="$(app_version_of_path "$existing")"
    cask_ver="$(cask_latest_version "$token")"

    if [[ "$ADOPT" -eq 1 ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        info "发现手动安装：$existing${app_ver:+（版本 ${app_ver}）}"
        info "将用 Homebrew 接管${cask_ver:+（Homebrew 最新 ${cask_ver}）}：brew install --cask --force $token"
        RESULT_STATUS="dry"
      else
        info "用 Homebrew 接管手动安装的 $token …"
        if "$BREW" install --cask --force "$token"; then
          RESULT_STATUS="installed"
        else
          RESULT_STATUS="failed"
          return 1
        fi
      fi
      return 0
    fi

    printf '  已手动安装：%s%s\n' "$existing" "${app_ver:+（版本 ${app_ver}）}"
    [[ -n "$cask_ver" ]] && printf '  Homebrew 最新：%s\n' "$cask_ver"
    info "未被 Homebrew 管理，本次跳过；想让它自动更新请加 --adopt。"
    RESULT_STATUS="manual"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "将安装：brew install --cask --force $token"
    RESULT_STATUS="dry"
  else
    info "安装 $token …"
    if "$BREW" install --cask --force "$token"; then
      RESULT_STATUS="installed"
    else
      RESULT_STATUS="failed"
      return 1
    fi
  fi
  return 0
}

process_formula() {
  local name="$1"

  if "$BREW" list --formula "$name" >/dev/null 2>&1; then
    if is_outdated_formula "$name"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        info "将升级：brew upgrade $name"
        RESULT_STATUS="dry"
      else
        info "升级 $name …"
        if "$BREW" upgrade "$name"; then
          RESULT_STATUS="updated"
        else
          RESULT_STATUS="failed"
          return 1
        fi
      fi
    else
      RESULT_STATUS="current"
    fi
  else
    if [[ "$DRY_RUN" -eq 1 ]]; then
      info "将安装：brew install $name"
      RESULT_STATUS="dry"
    else
      info "安装 $name …"
      if "$BREW" install "$name"; then
        RESULT_STATUS="installed"
      else
        RESULT_STATUS="failed"
        return 1
      fi
    fi
  fi
  return 0
}

process_npm() {
  local pkg="$1" before="$2"
  local latest=""

  if ! command -v npm >/dev/null 2>&1; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      info "将先安装 Node.js，再执行：npm install -g $pkg@latest"
      RESULT_STATUS="dry"
      return 0
    fi
    warn "npm 不可用，先安装 Node.js …"
    "$BREW" install node || {
      RESULT_STATUS="failed"
      return 1
    }
    hash -r 2>/dev/null || true
  fi

  # 先查询线上最新版本：当前已是最新就直接跳过，不再跑一遍安装
  [[ -z "$before" ]] && before="$(version_of npm "$pkg")"
  latest="$(npm view --fetch-retries=1 --fetch-timeout=20000 "$pkg" version 2>/dev/null | tail -1)"
  latest="$(printf '%s' "$latest" | tr -d '[:space:]')"

  if [[ -n "$before" && -n "$latest" && "$before" == "$latest" ]]; then
    RESULT_STATUS="current"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -n "$before" && -n "$latest" ]]; then
      info "将升级：npm install -g $pkg@latest（${before} → ${latest}）"
    else
      info "将执行：npm install -g $pkg@latest"
    fi
    RESULT_STATUS="dry"
    return 0
  fi

  info "npm install -g $pkg@latest …"
  if npm install -g --no-fund --no-audit "$pkg@latest"; then
    local after
    after=$(version_of npm "$pkg")
    if [[ -z "$before" ]]; then
      RESULT_STATUS="installed"
    elif [[ "$before" == "$after" ]]; then
      RESULT_STATUS="current"
    else
      RESULT_STATUS="updated"
    fi
  else
    RESULT_STATUS="failed"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# 结果汇总
# ---------------------------------------------------------------------------
RESULT_STATUSES=()
RESULT_LABELS=()
RESULT_VERSIONS=()
RESULT_KEYS=()
FAILED_LABELS=()
FAILED_KEYS=()

record_result() {
  RESULT_STATUSES+=("$1")
  RESULT_LABELS+=("$2")
  RESULT_VERSIONS+=("$3")
  RESULT_KEYS+=("$4")
}

run_item() {
  local idx="$1"
  local group="${ITEM_GROUP[$idx]}"
  local key="${ITEM_KEY[$idx]}"
  local label="${ITEM_LABEL[$idx]}"
  local type="${ITEM_TYPE[$idx]}"
  local id="${ITEM_ID[$idx]}"
  local note="${ITEM_NOTE[$idx]}"
  local fallback="${ITEM_FALLBACK[$idx]}"
  local before="" after=""
  local fb_note=""
  RESULT_STATUS=""

  # 已经通过 npm 装过、但 Homebrew 里没有的条目（例如 claude-code）：
  # 直接走 npm 更新，避免每次重复等待 cask 下载超时。
  if [[ "$type" == "cask" && "$fallback" == npm:* && -n "$BREW" ]]; then
    local fb_pkg="${fallback#npm:}"
    if ! "$BREW" list --cask "$id" >/dev/null 2>&1 \
       && command -v npm >/dev/null 2>&1 \
       && [[ -n "$(version_of npm "$fb_pkg")" ]]; then
      fb_note="已通过 npm 安装，本次直接用 npm 更新。"
      type="npm"
      id="$fb_pkg"
    fi
  fi

  printf '\n%s[%d/%d]%s %s\n' "$C_BOLD" "$ITEM_NO" "$TOTAL" "$C_RESET" "$label"
  printf '  %s%s %s%s\n' "$C_DIM" "$type" "$id" "$C_RESET"
  [[ -n "$note" ]] && printf '  %s%s%s\n' "$C_DIM" "$note" "$C_RESET"
  [[ -n "$fb_note" ]] && printf '  %s%s%s\n' "$C_DIM" "$fb_note" "$C_RESET"

  # 纯 CLI 的 cask：brew 账本里没有，但命令已在 PATH 里（手动 npm/下载安装）
  # → 视为已安装并跳过；--adopt 时继续走 brew 接管。
  if [[ "$type" == "cask" && -n "$BREW" && "$ADOPT" -ne 1 ]]; then
    local _bin _bp _appname _tgt
    _appname="$(app_name_for_key "$key")"
    _bin="$(cli_bin_for_key "$key")"
    if [[ -z "$_appname" && -n "$_bin" ]] \
       && ! "$BREW" list --cask "$id" >/dev/null 2>&1; then
      _bp="$(command -v "$_bin" 2>/dev/null || true)"
      if [[ -n "$_bp" && -x "$_bp" ]]; then
        # 排除 Homebrew 自己的 shim：指向 Caskroom / Cellar 的符号链接
        _tgt="$(readlink "$_bp" 2>/dev/null || true)"
        case "$_tgt" in
          *Caskroom*|*Cellar*) _bp="" ;;
        esac
      fi
      if [[ -n "$_bp" && -x "$_bp" ]]; then
        printf '  已存在命令：%s\n' "$_bp"
        info "未被 Homebrew 管理，本次跳过；想交给 Homebrew 管理请加 --adopt。"
        RESULT_STATUS="manual"
        record_result "$RESULT_STATUS" "$label" "" "$key"
        return 0
      fi
    fi
  fi

  if [[ -n "$BREW" ]]; then
    before=$(version_of "$type" "$id")
    [[ -n "$before" ]] && printf '  当前版本：%s\n' "$before"
  fi

  if [[ "$DRY_RUN" -eq 1 && -z "$BREW" ]]; then
    info "将安装（需先安装 Homebrew）：$type $id"
    RESULT_STATUS="dry"
  else
    case "$type" in
      cask)    process_cask "$id" "$(app_name_for_key "$key")" ;;
      formula) process_formula "$id" "$before" ;;
      npm)     process_npm "$id" "$before" ;;
      *)
        err "未知类型：$type"
        RESULT_STATUS="failed"
        ;;
    esac

    # 主来源失败时的备用安装方式，例如 npm:@anthropic-ai/claude-code
    if [[ "$RESULT_STATUS" == "failed" && -n "$fallback" ]]; then
      case "$fallback" in
        npm:*)
          warn "Homebrew 下载失败，改用 npm 安装 ${fallback#npm:} …"
          process_npm "${fallback#npm:}" ""
          if [[ "$RESULT_STATUS" != "failed" ]]; then
            after=$(version_of npm "${fallback#npm:}")
            RESULT_FALLBACK_USED=1
          fi
          ;;
        *)
          warn "未知备用方式：$fallback"
          ;;
      esac
    fi
  fi

  if [[ -n "$BREW" && -z "$after" ]]; then
    after=$(version_of "$type" "$id")
  fi
  [[ -z "$after" && -n "$before" ]] && after="$before"

  # 手动安装的 App：版本从 Info.plist 读，brew 账本里没有
  if [[ "$RESULT_STATUS" == "manual" && -z "$after" ]]; then
    local _mp
    _mp="$(app_path_by_name "$(app_name_for_key "$key")" 2>/dev/null || true)"
    [[ -n "$_mp" ]] && after="$(app_version_of_path "$_mp")"
  fi

  case "$RESULT_STATUS" in
    installed)
      ok "已安装${after:+  $after}"
      ;;
    updated)
      ok "已更新${after:+  $after}"
      ;;
    current)
      printf '  %s● 已是最新%s%s\n' "$C_GREEN" "$C_RESET" "${after:+  $after}"
      ;;
    manual)
      printf '  %s● 手动安装，已跳过%s%s\n' "$C_YELLOW" "$C_RESET" "${after:+  $after}"
      ;;
    dry)
      printf '  %s- 预演，未执行%s\n' "$C_YELLOW" "$C_RESET"
      ;;
    failed)
      err "失败：${label}（${type} ${id}）"
      FAILED=$((FAILED + 1))
      FAILED_LABELS+=("${label} [${key}]")
      FAILED_KEYS+=("${key}")
      ;;
    *)
      err "未知结果：${RESULT_STATUS}"
      FAILED=$((FAILED + 1))
      FAILED_LABELS+=("${label} [${key}]")
      FAILED_KEYS+=("${key}")
      ;;
  esac

  record_result "$RESULT_STATUS" "$label" "$after" "$key"
}

count_status() {
  local wanted="$1" n=0 s
  for s in "${RESULT_STATUSES[@]}"; do
    [[ "$s" == "$wanted" ]] && n=$((n + 1))
  done
  printf '%s' "$n"
}

print_summary() {
  local end_ts elapsed mins secs
  end_ts=$(date +%s)
  elapsed=$((end_ts - START_TS))
  mins=$((elapsed / 60))
  secs=$((elapsed % 60))

  section "执行结果"

  printf '  %s✓ 新安装%s      %d 项\n' "$C_GREEN" "$C_RESET" "$(count_status installed)"
  printf '  %s↑ 已更新%s      %d 项\n' "$C_GREEN" "$C_RESET" "$(count_status updated)"
  printf '  %s● 已是最新%s    %d 项\n' "$C_GREEN" "$C_RESET" "$(count_status current)"
  if [[ "$(count_status manual)" -gt 0 ]]; then
    printf '  %s● 手动安装%s    %d 项  %s(未托管，跳过；加 --adopt 接管)%s\n' \
      "$C_YELLOW" "$C_RESET" "$(count_status manual)" "$C_DIM" "$C_RESET"
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '  %s- 预演%s        %d 项\n' "$C_YELLOW" "$C_RESET" "$(count_status dry)"
  fi
  if [[ "$FAILED" -gt 0 ]]; then
    printf '  %s✗ 失败%s        %d 项\n' "$C_RED" "$C_RESET" "$FAILED"
  fi

  if [[ "$FAILED" -gt 0 ]]; then
    printf '\n%s失败明细：%s\n' "$C_RED" "$C_RESET"
    local label
    for label in "${FAILED_LABELS[@]}"; do
      printf '  - %s\n' "$label"
    done
    printf '\n提示：可单独重试，例如 ./ai-stack.sh --only <key>\n'
    printf '      常见原因：网络超时、应用正在运行、代理未开。\n'
    case " ${FAILED_KEYS[*]} " in
      *" claude "*|*" claude-code "*)
        printf '      Claude 桌面版依赖 downloads.claude.ai，被墙时请加 --proxy 或改用 App Store 版。\n'
        ;;
    esac
  fi

  printf '\n耗时：%d 分 %d 秒\n' "$mins" "$secs"
  if [[ -n "$LOG_FILE" ]]; then
    printf '日志：%s\n' "${LOG_FILE/#$HOME/~}"
  fi

  if [[ "$FAILED" -gt 0 ]]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# 状态输出（机器可读，给 AI / 脚本用）
# ---------------------------------------------------------------------------
json_quote() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  printf '%s' "$s"
}

print_status_json() {
  local i first=1 sel installed ver via app_path bin_name bin_path bin_tgt
  local have_brew="false"
  [[ -n "$BREW" ]] && have_brew="true"

  printf '{\n'
  printf '"script":"ai-stack",\n'
  printf '"version":"%s",\n' "$SCRIPT_VERSION"
  printf '"macos":"%s",\n' "$(sw_vers -productVersion 2>/dev/null)"
  printf '"arch":"%s",\n' "$(uname -m)"
  printf '"host":"%s",\n' "$(json_quote "$(hostname)")"
  printf '"homebrew_installed":%s,\n' "$have_brew"
  printf '"filters":{"only":"%s","skip":"%s","no_recommend":%s,"no_claude":%s},\n' \
    "$(json_quote "$ONLY")" "$(json_quote "$SKIP")" "$NO_RECOMMEND" "$NO_CLAUDE"
  printf '"items":[\n'

  for i in "${!ITEM_KEY[@]}"; do
    [[ $first -eq 1 ]] || printf ',\n'
    first=0

    if is_selected "${ITEM_KEY[$i]}" "${ITEM_GROUP[$i]}"; then
      sel="true"
    else
      sel="false"
    fi

    installed="false"
    ver=""
    via=""
    if [[ -n "$BREW" ]]; then
      ver="$(version_of "${ITEM_TYPE[$i]}" "${ITEM_ID[$i]}" 2>/dev/null)"
      if [[ -n "$ver" ]]; then
        installed="true"
        via="${ITEM_TYPE[$i]}"
      fi
    fi

    # 主来源没有、但备用来源（npm）已装：同样视为已安装
    if [[ "$installed" != "true" && -n "${ITEM_FALLBACK[$i]}" ]]; then
      case "${ITEM_FALLBACK[$i]}" in
        npm:*)
          ver="$(version_of npm "${ITEM_FALLBACK[$i]#npm:}" 2>/dev/null)"
          if [[ -n "$ver" ]]; then
            installed="true"
            via="npm"
          fi
          ;;
      esac
    fi

    # 都没找到：再看 /Applications 里是否有手动安装的同名 App
    if [[ "$installed" != "true" && "${ITEM_TYPE[$i]}" == "cask" ]]; then
      app_path="$(app_path_by_name "$(app_name_for_key "${ITEM_KEY[$i]}")" 2>/dev/null || true)"
      if [[ -n "$app_path" ]]; then
        installed="true"
        via="app"
        ver="$(app_version_of_path "$app_path")"
      else
        # 纯 CLI：brew 没有，但命令已在 PATH 里（手动安装）
        bin_name="$(cli_bin_for_key "${ITEM_KEY[$i]}")"
        if [[ -n "$bin_name" ]]; then
          bin_path="$(command -v "$bin_name" 2>/dev/null || true)"
          if [[ -n "$bin_path" && -x "$bin_path" ]]; then
            bin_tgt="$(readlink "$bin_path" 2>/dev/null || true)"
            case "$bin_tgt" in
              *Caskroom*|*Cellar*) ;;
              *)
                installed="true"
                via="bin"
                ;;
            esac
          fi
        fi
      fi
    fi

    printf '{"key":"%s","group":"%s","label":"%s","type":"%s","id":"%s","fallback":"%s","note":"%s","selected":%s,"installed":%s,"via":"%s","version":"%s"}' \
      "$(json_quote "${ITEM_KEY[$i]}")" \
      "$(json_quote "${ITEM_GROUP[$i]}")" \
      "$(json_quote "${ITEM_LABEL[$i]}")" \
      "$(json_quote "${ITEM_TYPE[$i]}")" \
      "$(json_quote "${ITEM_ID[$i]}")" \
      "$(json_quote "${ITEM_FALLBACK[$i]}")" \
      "$(json_quote "${ITEM_NOTE[$i]}")" \
      "$sel" "$installed" "$via" "$ver"
  done

  printf '\n]\n}\n'
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
if [[ "$LIST_ONLY" -eq 1 ]]; then
  show_list
  exit 0
fi

if [[ "$STATUS_ONLY" -eq 1 ]]; then
  find_brew
  if [[ -n "$BREW_BIN" ]]; then
    eval "$("$BREW_BIN" shellenv)"
    BREW="$BREW_BIN"
  fi
  print_status_json
  exit 0
fi

init_log

trap 'printf "\n%s已取消。%s\n" "$C_YELLOW" "$C_RESET"; exit 130' INT TERM

printf '%s%sAI 工具栈 · 一键安装 / 更新%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
printf 'macOS %s（%s）· %s\n' "$(sw_vers -productVersion 2>/dev/null)" "$(uname -m)" "$(date '+%Y-%m-%d %H:%M')"
printf '脚本版本 %s\n' "$SCRIPT_VERSION"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s模式：预演（不会修改系统）%s\n' "$C_YELLOW" "$C_RESET"
fi
if [[ -n "$ONLY" ]]; then
  printf '仅处理：%s\n' "$ONLY"
fi
if [[ -n "$SKIP" ]]; then
  printf '跳过：%s\n' "$SKIP"
fi
if [[ "$NO_RECOMMEND" -eq 1 ]]; then
  printf '不安装推荐补充分组。\n'
fi
if [[ "$NO_CLAUDE" -eq 1 ]]; then
  printf '跳过 Claude 桌面版和 Claude Code。\n'
fi
if [[ "$ADOPT" -eq 1 ]]; then
  printf '接管模式：/Applications 里手动安装的同名 App 会交给 Homebrew 管理。\n'
fi

# 代理
if [[ -n "$PROXY" ]]; then
  export HTTP_PROXY="$PROXY"  HTTPS_PROXY="$PROXY"  ALL_PROXY="$PROXY"
  export http_proxy="$PROXY" https_proxy="$PROXY" all_proxy="$PROXY"
  export NO_PROXY="localhost,127.0.0.1,::1"
  export no_proxy="localhost,127.0.0.1,::1"
  printf '代理：%s\n' "$PROXY"
fi

# 国内镜像
if [[ "$USE_CN" -eq 1 ]]; then
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  printf 'Homebrew 镜像：清华 TUNA\n'
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

validate_selection
TOTAL=$(count_selected)
if [[ "$TOTAL" -eq 0 ]]; then
  err "没有匹配的条目。用 ./ai-stack.sh --list 查看可用键名。"
  exit 2
fi

section "准备 Homebrew"
ensure_brew

if [[ "$NO_UPDATE" -eq 0 && "$DRY_RUN" -eq 0 && -n "$BREW" ]]; then
  section "更新 Homebrew 索引"
  info "brew update（如失败会继续使用本地索引）…"
  "$BREW" update --quiet || warn "brew update 失败，继续使用现有索引。"
fi

OUTDATED_CASKS=""
OUTDATED_FORMULAS=""
if [[ -n "$BREW" ]]; then
  info "检查可更新项 …"
  greedy_arg="--greedy"
  [[ "$NO_GREEDY" -eq 1 ]] && greedy_arg=""
  OUTDATED_CASKS=$("$BREW" outdated --cask $greedy_arg --quiet 2>/dev/null | tr '\n' ' ')
  OUTDATED_FORMULAS=$("$BREW" outdated --formula --quiet 2>/dev/null | tr '\n' ' ')
fi

CURRENT_GROUP=""
ITEM_NO=0
for i in "${!ITEM_KEY[@]}"; do
  is_selected "${ITEM_KEY[$i]}" "${ITEM_GROUP[$i]}" || continue

  if [[ "${ITEM_GROUP[$i]}" != "$CURRENT_GROUP" ]]; then
    CURRENT_GROUP="${ITEM_GROUP[$i]}"
    section "$(group_title "$CURRENT_GROUP")"
  fi

  ITEM_NO=$((ITEM_NO + 1))
  run_item "$i"
done

if [[ "$DO_CLEANUP" -eq 1 && "$DRY_RUN" -eq 0 && -n "$BREW" ]]; then
  section "清理 Homebrew 缓存"
  "$BREW" cleanup --prune=7 || warn "brew cleanup 失败（不影响已安装工具）。"
fi

print_summary
exit $?
