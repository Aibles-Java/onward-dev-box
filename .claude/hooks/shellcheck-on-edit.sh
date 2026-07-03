#!/usr/bin/env bash
# PostToolUse hook (Edit|Write) — runs shellcheck on edited .sh files and
# reports findings back as context. Never blocks: always exits 0.
set -uo pipefail

command -v shellcheck >/dev/null 2>&1 || exit 0

input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import sys,json;
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception:
    print("")' 2>/dev/null || echo "")"

case "$file" in
  *.sh) [ -f "$file" ] || exit 0 ;;
  *) exit 0 ;;
esac

out="$(shellcheck --format=gcc "$file" 2>/dev/null || true)"
if [ -n "$out" ]; then
  echo "shellcheck findings for $file:"
  echo "$out"
fi
exit 0
