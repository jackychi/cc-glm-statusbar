#!/bin/bash
# cc-glm-statusbar — Claude Code 状态栏（纯 z.ai / 智谱 GLM 版）
# Line 1: 会话信息（模型、目录、git、context 用量、cache token）
# Line 2: GLM Coding Plan 用量（套餐、5 小时 / 每周 Token 额度、MCP 月调用）
# 依赖: curl, jq
# 鉴权: 复用 Claude Code 的 ANTHROPIC_AUTH_TOKEN / ANTHROPIC_API_KEY，无需额外密钥

set -o pipefail

# ── Colors ───────────────────────────────────────────────────────────
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────
# 大数格式化: 856 → "856", 15234 → "15.2k", 1523400 → "1.5M"
fmt_num() {
    local n=${1:-0}
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1fM\", $n/1000000}"
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        awk "BEGIN{printf \"%.1fk\", $n/1000}"
    else
        echo "$n"
    fi
}

# 缓存是否过期: 文件不存在或超过 max_age 秒
cache_is_stale() {
    local file=$1 max_age=$2
    [ ! -f "$file" ] && return 0
    local now; now=$(date +%s)
    local mtime; mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
    [ $(( now - mtime )) -gt "$max_age" ]
}

# 用量进度条（用得越多越红）: pct, 宽度=5
make_usage_bar() {
    local pct=$1 width=5
    local filled=$(( pct * width / 100 ))
    # 任意非零用量至少显示一格，避免 19% 在 width=5 时被 floor 成空条
    [ "$pct" -gt 0 ] && [ "$filled" -lt 1 ] && filled=1
    [ "$filled" -gt "$width" ] && filled=$width
    local empty=$(( width - filled ))
    local color
    if [ "$pct" -ge 90 ]; then color="$RED"
    elif [ "$pct" -ge 70 ]; then color="$YELLOW"
    else color="$GREEN"; fi
    local bar=""
    [ "$filled" -gt 0 ] && printf -v f "%${filled}s" && bar="${f// /█}"
    [ "$empty" -gt 0 ] && printf -v e "%${empty}s" && bar="${bar}${e// /░}"
    printf '%b' "${color}${bar}${RESET}"
}

# ── 读取 Claude Code 会话数据 ────────────────────────────────────────
input=$(cat)

MODEL_ID=$(echo "$input" | jq -r '.model.id // .model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
SESSION_ID=$(echo "$input" | jq -r '.session_id // "default"')

# current_usage: 最近一次 API 调用的 token 明细（首次调用前为 null）
CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CACHE_WRITE=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')

# ── Context 用量进度条 ───────────────────────────────────────────────
if [ "$USED_PCT" -ge 90 ] 2>/dev/null; then CTX_COLOR="$RED"
elif [ "$USED_PCT" -ge 70 ] 2>/dev/null; then CTX_COLOR="$YELLOW"
else CTX_COLOR="$GREEN"; fi

BAR_WIDTH=10
CTX_FILLED=$(( USED_PCT * BAR_WIDTH / 100 ))
CTX_EMPTY=$(( BAR_WIDTH - CTX_FILLED ))
CTX_BAR=""
[ "$CTX_FILLED" -gt 0 ] && printf -v FILL "%${CTX_FILLED}s" && CTX_BAR="${FILL// /█}"
[ "$CTX_EMPTY" -gt 0 ] && printf -v PAD "%${CTX_EMPTY}s" && CTX_BAR="${CTX_BAR}${PAD// /░}"

C_READ=$(fmt_num "$CACHE_READ")
C_WRITE=$(fmt_num "$CACHE_WRITE")

CACHE_PART=""
if [ "$CACHE_READ" -gt 0 ] 2>/dev/null || [ "$CACHE_WRITE" -gt 0 ] 2>/dev/null; then
    CACHE_PART=" ${DIM}|${RESET} 💾 ${DIM}r${RESET}${C_READ} ${DIM}w${RESET}${C_WRITE}"
fi

# ── Git 分支（按 session 缓存, 5s TTL）─────────────────────────────
GIT_CACHE="/tmp/cc-glm-sl-git-${SESSION_ID}"
GIT_CACHE_AGE=5

if cache_is_stale "$GIT_CACHE" "$GIT_CACHE_AGE"; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        DIRTY=""
        [ -n "$(git status --porcelain 2>/dev/null | head -1)" ] && DIRTY="*"
        echo "${BRANCH}${DIRTY}" > "$GIT_CACHE"
    else
        echo "" > "$GIT_CACHE"
    fi
fi
GIT_INFO=$(cat "$GIT_CACHE" 2>/dev/null || echo "")

# ── Line 1: 会话信息 ────────────────────────────────────────────────
GIT_PART=""
[ -n "$GIT_INFO" ] && GIT_PART=" ${DIM}|${RESET} 🌿 ${GIT_INFO}"

printf '%b' "${CYAN}${BOLD}[${MODEL_ID}]${RESET} 📁 ${DIR##*/}${GIT_PART} ${DIM}|${RESET} ${CTX_COLOR}${CTX_BAR}${RESET} ${USED_PCT}% ctx${CACHE_PART}\n"

# ── Line 2: GLM Coding Plan 用量 ────────────────────────────────────
# 识别区域（从 ANTHROPIC_BASE_URL 推断）和 API Key（复用 Claude Code 的鉴权）
ZAI_API_BASE="https://api.z.ai"
ZAI_KEY="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-}}"
BASE_URL="${ANTHROPIC_BASE_URL:-}"
if echo "$BASE_URL" | grep -q "open\.bigmodel\.cn"; then
    ZAI_API_BASE="https://open.bigmodel.cn"
fi

# 没有 Key —— 给出轻量提示，不阻塞状态栏
if [ -z "$ZAI_KEY" ]; then
    printf '%b' "${DIM}⚙ 配置${RESET} ${YELLOW}ANTHROPIC_AUTH_TOKEN${RESET} ${DIM}显示 GLM 用量 →${RESET} ${CYAN}z.ai/manage-apikey${RESET}\n"
    exit 0
fi

# 缓存 120s，全局共享（用量接口每次返回实时快照，没必要高频刷新）
ZAI_CACHE="/tmp/cc-glm-sl-account-cache"
ZAI_CACHE_AGE=120

if cache_is_stale "$ZAI_CACHE" "$ZAI_CACHE_AGE"; then
    TMP=$(mktemp)
    curl -s --max-time 5 "${ZAI_API_BASE}/api/monitor/usage/quota/limit" \
        -H "Authorization: ${ZAI_KEY}" \
        -H "Content-Type: application/json" > "$TMP"
    # 校验通过才落盘，避免把错误响应/空响应缓存住
    if jq -e '.data' "$TMP" > /dev/null 2>&1; then
        mv "$TMP" "$ZAI_CACHE"
    else
        rm -f "$TMP"
    fi
fi

# 无可用缓存则跳过第二行（网络抖动 / 接口异常时不破坏第一行）
[ ! -f "$ZAI_CACHE" ] && exit 0
CACHED=$(cat "$ZAI_CACHE")

if echo "$CACHED" | jq -e '.data.limits' > /dev/null 2>&1; then
    ZAI_LEVEL=$(echo "$CACHED" | jq -r '.data.level // "—"')
    # 按 unit 区分窗口: unit=3 → 5 小时 Token 额度, unit=6 → 每周 Token 额度
    ZAI_5H_PCT=$(echo "$CACHED" | jq -r '[.data.limits[] | select(.type=="TOKENS_LIMIT" and .unit==3)][0].percentage // 0')
    ZAI_WEEKLY_PCT=$(echo "$CACHED" | jq -r '[.data.limits[] | select(.type=="TOKENS_LIMIT" and .unit==6)][0].percentage // 0')
    # TIME_LIMIT = MCP 工具调用次数（月）
    ZAI_MCP_CUR=$(echo "$CACHED" | jq -r '[.data.limits[] | select(.type=="TIME_LIMIT")][0].currentValue // 0')
    ZAI_MCP_MAX=$(echo "$CACHED" | jq -r '[.data.limits[] | select(.type=="TIME_LIMIT")][0].usage // 0')

    ZAI_5H_BAR=$(make_usage_bar "$ZAI_5H_PCT")
    ZAI_WEEKLY_BAR=$(make_usage_bar "$ZAI_WEEKLY_PCT")

    ZAI_MCP_PART=""
    if [ "$ZAI_MCP_MAX" -gt 0 ] 2>/dev/null; then
        ZAI_MCP_PART=" ${DIM}·${RESET} MCP ${ZAI_MCP_CUR}/${ZAI_MCP_MAX}"
    fi

    # 套餐等级首字母大写（awk 写法兼容 macOS 自带的 bash 3.2）
    ZAI_LEVEL_FMT=$(echo "$ZAI_LEVEL" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    [ -z "$ZAI_LEVEL_FMT" ] && ZAI_LEVEL_FMT="—"

    printf '%b' "🤖 ${BOLD}GLM ${ZAI_LEVEL_FMT}${RESET} ${DIM}|${RESET} 5h ${ZAI_5H_BAR} ${ZAI_5H_PCT}% ${DIM}·${RESET} W ${ZAI_WEEKLY_BAR} ${ZAI_WEEKLY_PCT}%${ZAI_MCP_PART}\n"
fi
