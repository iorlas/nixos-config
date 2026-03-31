#!/usr/bin/env bash
# Kay statusline v4
# Receives session JSON on stdin

input=$(cat)

# ── Colors ──
R="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
ORANGE="\033[38;5;208m"
RED="\033[31m"
MAGENTA="\033[35m"
BLUE="\033[34m"
SEP="${DIM} │ ${R}"

# ── Parse JSON ──
eval "$(echo "$input" | jq -r '
  @sh "workdir=\(.workspace.current_dir // ".")",
  @sh "model=\(.model.display_name // "Claude")",
  @sh "used_pct=\(.context_window.used_percentage // "")",
  @sh "ctx_size=\(.context_window.context_window_size // "")",
  @sh "cost=\(.cost.total_cost_usd // "")",
  @sh "added=\(.cost.total_lines_added // "0")",
  @sh "removed=\(.cost.total_lines_removed // "0")"
')"

# ── Model (shorten: Opus 4.6 → O4.6, Sonnet 4.6 → S4.6, Haiku 4.5 → H4.5) ──
short_model=$(echo "$model" | sed -E 's/^(Opus|Claude Opus) /O/; s/^(Sonnet|Claude Sonnet) /S/; s/^(Haiku|Claude Haiku) /H/; s/^Claude //')
model_str="${DIM}${short_model}${R}"

# ── Folder ──
dir_str="${BLUE}${workdir##*/}${R}"

# ── Git branch + dirty (fast: diff-index instead of status --porcelain) ──
branch=$(git -C "$workdir" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
    dirty=""
    git -C "$workdir" diff-index --quiet HEAD -- 2>/dev/null || dirty="${YELLOW}*${R}"
    branch_str="${MAGENTA}${branch}${dirty}${R}"
else
    branch_str=""
fi

# ── Context — used tokens + emoji urgency ──
if [ -n "$used_pct" ] && [ -n "$ctx_size" ]; then
    pct=${used_pct%.*}
    used_tokens=$(( ctx_size * pct / 100 ))

    if [ "$used_tokens" -ge 1000000 ]; then
        used_fmt="$(( used_tokens / 1000000 )).$(( (used_tokens % 1000000) / 100000 ))m"
    else
        used_fmt="$(( used_tokens / 1000 ))k"
    fi

    if [ "$pct" -lt 50 ]; then
        ctx_str="${DIM}${used_fmt}${R}"
    elif [ "$pct" -lt 70 ]; then
        ctx_str="${YELLOW}${used_fmt}${R}"
    elif [ "$pct" -lt 85 ]; then
        ctx_str="${ORANGE}⚡${used_fmt}${R}"
    elif [ "$pct" -lt 92 ]; then
        ctx_str="${BOLD}${RED}🔥${used_fmt}${R}"
    else
        ctx_str="\033[5;31m💀${used_fmt}${R}"
    fi
else
    ctx_str="${DIM}-${R}"
fi

# ── Cost — whole dollars only, hidden when zero ──
if [ -n "$cost" ]; then
    cost_int=$(printf '%.0f' "$cost")
    if [ "$cost_int" -gt 0 ]; then
        if [ "$cost_int" -lt 3 ]; then cc="$GREEN"
        elif [ "$cost_int" -lt 5 ]; then cc="$YELLOW"
        elif [ "$cost_int" -lt 10 ]; then cc="$ORANGE"
        else cc="$RED"; fi
        cost_str="${cc}\$${cost_int}${R}"
    else
        cost_str=""
    fi
else
    cost_str=""
fi

# ── Code churn ──
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
    churn_str="${GREEN}+${added}${R}${RED}-${removed}${R}"
else
    churn_str=""
fi

# ── Assemble ──
out="${model_str}${SEP}${dir_str}"
[ -n "$branch_str" ] && out+="${SEP}${branch_str}"
out+="${SEP}${ctx_str}"
[ -n "$cost_str" ] && out+="${SEP}${cost_str}"
[ -n "$churn_str" ] && out+="${SEP}${churn_str}"

printf '%b' "$out"
