#!/usr/bin/env bash
# Claude Code status line, modeled on ~/.config/starship.toml:
#   $directory$git_branch$git_status  then model | ctx | 5h and weekly plan usage left
# Starship's cmd_duration and prompt character have no status-line meaning, so they are omitted.
input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$PWD
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

CYAN=$'\033[1;36m'; PURPLE=$'\033[1;35m'; RED=$'\033[1;31m'; DIM=$'\033[2m'; RESET=$'\033[0m'

# Directory: starship default - repo-relative inside git, ~ for home, last 3 components.
toplevel=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$toplevel" ]; then
  repo=$(basename "$toplevel")
  rel=${cwd#"$toplevel"}
  dir="$repo$rel"
else
  dir=${cwd/#$HOME/\~}
fi
dir=$(printf '%s' "$dir" | awk -F/ '{ if (NF > 3) { print $(NF-2) "/" $(NF-1) "/" $NF } else { print } }')
out="${CYAN}${dir}${RESET}"

# Git branch and status (starship symbols), skipping optional locks so it never blocks git.
if [ -n "$toplevel" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && out="$out on ${PURPLE} ${branch}${RESET}"
  st=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  flags=""
  printf '%s\n' "$st" | grep -q '^[MADRC]' && flags="${flags}+"
  printf '%s\n' "$st" | grep -q '^.[MD]' && flags="${flags}!"
  printf '%s\n' "$st" | grep -q '^??' && flags="${flags}?"
  [ -n "$flags" ] && out="$out ${RED}[${flags}]${RESET}"
fi

# Model, context used, and plan usage left. Claude Code passes the subscription's
# 5-hour and weekly windows as rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}.
info="$model"
[ -n "$used" ] && info="$info | ctx: $(printf '%.0f' "$used")% used"

# quota_left <window-key> <label> <date-format>: "5h: 97% left (9pm)", red when under 20% left.
quota_left() {
  local pct reset left text
  pct=$(printf '%s' "$input" | jq -r ".rate_limits.$1.used_percentage // empty")
  [ -z "$pct" ] && return
  left=$(( 100 - $(printf '%.0f' "$pct") ))
  [ "$left" -lt 0 ] && left=0
  text="$2: ${left}% left"
  reset=$(printf '%s' "$input" | jq -r ".rate_limits.$1.resets_at // empty")
  [ -n "$reset" ] && text="$text ($(date -r "$reset" "$3" 2>/dev/null | sed -e 's/AM$/am/' -e 's/PM$/pm/' -e 's/^0//'))"
  if [ "$left" -lt 20 ]; then
    printf '%s%s%s%s' "$RESET" "$RED" "$text" "$RESET$DIM"
  else
    printf '%s' "$text"
  fi
}
q5=$(quota_left five_hour 5h '+%I%p')
qw=$(quota_left seven_day wk '+%a')
[ -n "$q5" ] && info="$info | $q5"
[ -n "$qw" ] && info="$info | $qw"
[ -n "$info" ] && out="$out ${DIM}${info}${RESET}"

printf '%s' "$out"
