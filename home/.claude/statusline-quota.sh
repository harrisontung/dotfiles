#!/usr/bin/env bash
# Cached quota summary for the Claude Code status line.
# Refreshes at most once per CACHE_MAX_AGE seconds so the status line stays fast;
# fails silently (prints nothing) on any error so a stalled/failing quota-axi
# call never breaks or blanks the status line.
set -u

# Homebrew Node 26 cannot verify HTTPS against the system CA store; without
# this, quota-axi serves a stale cached reading ("fetch failed"). Set here too
# so it works in sessions started before the dotfiles NODE_OPTIONS change.
export NODE_OPTIONS="${NODE_OPTIONS:---use-bundled-ca}"

CACHE_FILE="$HOME/.claude/.quota-statusline-cache.json"
CACHE_MAX_AGE=60

now=$(date +%s)
age=999999
if [ -f "$CACHE_FILE" ]; then
  mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
  [ -n "$mtime" ] && age=$((now - mtime))
fi

if [ "$age" -ge "$CACHE_MAX_AGE" ]; then
  fresh=$(npx -y quota-axi --provider claude --json 2>/dev/null)
  if [ -n "$fresh" ]; then
    echo "$fresh" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
  fi
fi

[ -f "$CACHE_FILE" ] || exit 0
json=$(cat "$CACHE_FILE" 2>/dev/null) || exit 0
[ -n "$json" ] || exit 0

five_hour=$(echo "$json" | jq -r '.providers[0].windows[]? | select(.id=="five_hour") | .percentRemaining // empty' 2>/dev/null)
week=$(echo "$json" | jq -r '.providers[0].windows[]? | select(.id=="seven_day") | .percentRemaining // empty' 2>/dev/null)

[ -z "$five_hour" ] && exit 0

mark_5h=""
mark_wk=""
case "$five_hour" in ''|*[!0-9]*) ;; *) [ "$five_hour" -lt 20 ] && mark_5h="!";; esac
case "$week" in ''|*[!0-9]*) ;; *) [ "$week" -lt 20 ] && mark_wk="!";; esac

if [ -n "$week" ]; then
  printf 'q:5h=%s%%%s wk=%s%%%s' "$five_hour" "$mark_5h" "$week" "$mark_wk"
else
  printf 'q:5h=%s%%%s' "$five_hour" "$mark_5h"
fi
