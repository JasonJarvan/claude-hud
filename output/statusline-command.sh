#!/usr/bin/env bash

input=$(cat)
# Colors
reset=$'\033[0m'
green=$'\033[32m'
red=$'\033[31m'
gold=$'\033[38;5;220m'
purple=$'\033[38;5;135m'

# --- Line 1: Model + Git + Context ---

# Model
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')

# Current directory (shorten home to ~)
raw_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
display_dir="${raw_dir/#$HOME/\~}"

# Git branch + diff stats
branch=$(git -C "$raw_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  diff_stats=$(git -C "$raw_dir" diff --shortstat HEAD 2>/dev/null)
  added=$(echo "$diff_stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  deleted=$(echo "$diff_stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
  [ -z "$added" ] && added=0
  [ -z "$deleted" ] && deleted=0
  git_info="🌿 ${branch} ${green}+${added}${reset}/${red}-${deleted}${reset}"
else
  git_info="🌿 no git"
fi

# Context bar
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
used_int=${used_pct%.*}
used_int=${used_int:-0}

if [ "$used_int" -lt 50 ]; then
  ctx_color=$'\033[32m'   # green
elif [ "$used_int" -lt 80 ]; then
  ctx_color=$'\033[33m'   # yellow
else
  ctx_color=$'\033[31m'   # red
fi

context_num="${ctx_color}${used_int}%${reset}"

# --- Line 2: Cost + Time remaining (cached, refreshes every 5 min) ---

cache_file="$HOME/.claude/ccusage-cache.json"
cache_max_age=300  # 5 minutes in seconds

needs_refresh=1
if [ -f "$cache_file" ]; then
  cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
  now=$(date +%s)
  if [ $(( now - cache_mtime )) -lt $cache_max_age ]; then
    needs_refresh=0
  fi
fi

if [ "$needs_refresh" -eq 1 ]; then
  ccusage_out=$(ccusage blocks --json 2>/dev/null)
  if [ -n "$ccusage_out" ] && echo "$ccusage_out" | jq . >/dev/null 2>&1; then
    echo "$ccusage_out" > "$cache_file"
  fi
fi

if [ -f "$cache_file" ]; then
  ccusage_out=$(cat "$cache_file")
  active_block=$(echo "$ccusage_out" | jq '[.blocks[] | select(.isActive == true)] | last')
  if [ -z "$active_block" ] || [ "$active_block" = "null" ]; then
    active_block=$(echo "$ccusage_out" | jq '.blocks | last')
  fi

  cost_usd=$(echo "$active_block" | jq -r '.costUSD // 0')
  cost_str=$(printf "\$%.2f" "$cost_usd")

  end_time=$(echo "$active_block" | jq -r '.endTime // empty')
  remain_mins=$(echo "$active_block" | jq -r '.projection.remainingMinutes // empty')
  if [ -n "$end_time" ]; then
    end_epoch=$(date -jf "%Y-%m-%dT%H:%M:%S" "${end_time%%.*}" +%s 2>/dev/null || \
                date -d "${end_time}" +%s 2>/dev/null || \
                echo "0")
    now_epoch=$(date +%s)
    diff_secs=$(( end_epoch - now_epoch ))
    if [ "$diff_secs" -gt 0 ]; then
      reset_mins=$(( diff_secs / 60 ))
      if [ -n "$remain_mins" ] && [ "$remain_mins" != "null" ]; then
        time_str="${green}${reset_mins}m reset${reset}/${red}${remain_mins}m remain${reset}"
      else
        time_str="${green}${reset_mins}m reset${reset}"
      fi
    else
      time_str="resetting…"
    fi
  else
    time_str="—"
  fi
else
  cost_str="—"
  time_str="—"
fi

# --- Output ---
echo "${context_num}|${purple}${model}${reset}|📁 ${display_dir}|${git_info}|${gold}${cost_str}${reset}|${time_str}"
