#!/usr/bin/env bash
# Claude Code status line: RGB gradient, dynamic emoji, quota, code velocity

input=$(cat)

# ── Colors ──
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Truecolor helper ──
rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

# ── Parse JSON fields ──
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_del=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
rl5_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl7_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl7_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ── Git info ──
branch=""
repo=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  top=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
  repo=$(basename "$top" 2>/dev/null)
fi

# ── Context bar: RGB gradient, full blocks only ──
BAR_WIDTH=20

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")

  # Round to nearest block
  filled=$(( (used_int * BAR_WIDTH + 50) / 100 ))

  bar=""
  for (( i=0; i<BAR_WIDTH; i++ )); do
    pos=$(( i * 100 / (BAR_WIDTH - 1) ))

    if [ "$pos" -le 50 ]; then
      r=$(( 0 + 220 * pos / 50 ))
      g=200
      b=$(( 80 - 80 * pos / 50 ))
    else
      adj=$(( pos - 50 ))
      r=220
      g=$(( 200 - 160 * adj / 50 ))
      b=$(( 0 + 20 * adj / 50 ))
    fi

    if [ "$i" -lt "$filled" ]; then
      bar="${bar}$(rgb $r $g $b)█"
    else
      bar="${bar}\033[38;2;60;60;60m░"
    fi
  done
  bar="${bar}${RESET}"

  if [ "$used_int" -ge 90 ]; then status_emoji="🚨"
  elif [ "$used_int" -ge 70 ]; then status_emoji="🔥"
  elif [ "$used_int" -ge 20 ]; then status_emoji="⚡"
  else status_emoji="🟢"; fi

  if [ "$used_int" -ge 90 ]; then pct_color="$RED"
  elif [ "$used_int" -ge 70 ]; then pct_color="$YELLOW"
  else pct_color="$GREEN"; fi

  ctx_part="${status_emoji} ${bar} ${DIM}ctx${RESET} ${pct_color}${used_int}%${RESET}"
else
  ctx_part="🟢 \033[38;2;60;60;60m░░░░░░░░░░░░░░░░░░░░${RESET} ${DIM}ctx${RESET} --%"
fi

# ── Cuota de uso: lo que queda y cuándo se reinicia ──
day_es() { case "$(date -r "$1" +%u)" in 1) echo lun;; 2) echo mar;; 3) echo mié;; 4) echo jue;; 5) echo vie;; 6) echo sáb;; 7) echo dom;; esac; }

quota_seg() {  # $1=etiqueta  $2=usado%  $3=reset (epoch)
  local left=$(( 100 - $(printf '%.0f' "$2") )) color
  [ "$left" -lt 0 ] && left=0
  if [ "$left" -le 10 ]; then color="$RED"
  elif [ "$left" -le 30 ]; then color="$YELLOW"
  else color="$GREEN"; fi
  local seg="$1:${color}${left}%${RESET}"
  [ -n "$3" ] && seg="${seg} ${DIM}↻$(day_es "$3") $(date -r "$3" +%H:%M)${RESET}"
  printf '%s' "$seg"
}

quota_part=""
[ -n "$rl5_used" ] && quota_part="left $(quota_seg 5h "$rl5_used" "$rl5_reset")"
if [ -n "$rl7_used" ]; then
  quota_part="${quota_part:-left}${quota_part:+  }$(quota_seg 7d "$rl7_used" "$rl7_reset")"
fi

# ── Ruta: el nombre del repo (amarillo) hace de último tramo, sin repetirlo ──
path_part=""
if [ -n "$cwd" ]; then
  if [ -n "$top" ] && [ -n "$repo" ]; then
    head="${top%/*}/"; tail="${cwd#$top}"
    path_part="${BOLD}${CYAN}${head/#$HOME/~}${RESET}${BOLD}${YELLOW}${repo}${RESET}"
    [ -n "$tail" ] && path_part="${path_part}${BOLD}${CYAN}${tail}${RESET}"
  else
    path_part="${BOLD}${CYAN}${cwd/#$HOME/~}${RESET}"
  fi
fi

# ── Code velocity ──
velocity="${GREEN}+${lines_add}${RESET} ${RED}-${lines_del}${RESET}"

# ── Single line ──
out=""
[ -n "$path_part" ] && out="${path_part}"
[ -n "$branch" ] && out="${out:+$out }${BOLD}${CYAN}🌿 (${branch})${RESET}"
out="${out:+$out ${DIM}|${RESET} }${ctx_part}"
[ -n "$quota_part" ] && out="${out} ${DIM}|${RESET} ${quota_part}"
out="${out} ${DIM}|${RESET} ${velocity}"
out="${out} ${DIM}|${RESET} ${MAGENTA}🤖 ${model}${RESET}"

printf '%b' "$out"
