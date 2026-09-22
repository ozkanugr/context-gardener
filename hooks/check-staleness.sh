#!/usr/bin/env bash
# context-gardener: SessionStart hook.
# Non-blocking. Never edits anything. Just tells Claude (via additionalContext)
# when the project's context files look bloated or haven't been groomed in a
# while, so it can offer to run /tidy-context. Zero external dependencies
# (no jq) so it runs anywhere bash + coreutils do.

set -euo pipefail

# --- tunables (override via env if you want different thresholds) ---
LINE_THRESHOLD="${CONTEXT_GARDENER_LINE_THRESHOLD:-150}"
DAYS_THRESHOLD="${CONTEXT_GARDENER_DAYS_THRESHOLD:-21}"

LOG_FILE=".claude/.context-gardener-log"

# --- find context files in scope ---
# Root/nested CLAUDE.md, plus any files under .claude/context/, skipping the
# usual noise directories. Silently no-op if nothing is found.
mapfile -t files < <(
  find . \
    \( -path '*/node_modules' -o -path '*/.git' -o -path '*/vendor' -o -path '*/dist' -o -path '*/build' \) -prune \
    -o \( -name 'CLAUDE.md' -o -path './.claude/context/*.md' \) -type f -print \
    2>/dev/null
)

if [ "${#files[@]}" -eq 0 ]; then
  exit 0
fi

total_lines=0
for f in "${files[@]}"; do
  n=$(wc -l < "$f" 2>/dev/null || echo 0)
  total_lines=$((total_lines + n))
done

now=$(date +%s)
last_groomed=""
days_since=""
if [ -f "$LOG_FILE" ]; then
  last_groomed=$(head -n1 "$LOG_FILE" 2>/dev/null | tr -dc '0-9' || true)
  if [ -n "$last_groomed" ]; then
    days_since=$(( (now - last_groomed) / 86400 ))
  fi
fi

nag=0
reason=""

if [ "$total_lines" -ge "$LINE_THRESHOLD" ]; then
  nag=1
  reason="totals ${total_lines} lines across ${#files[@]} file(s) (threshold: ${LINE_THRESHOLD})"
fi

if [ -n "$days_since" ] && [ "$days_since" -ge "$DAYS_THRESHOLD" ]; then
  nag=1
  if [ -n "$reason" ]; then
    reason="${reason}; also last groomed ${days_since} days ago (threshold: ${DAYS_THRESHOLD})"
  else
    reason="last groomed ${days_since} days ago (threshold: ${DAYS_THRESHOLD})"
  fi
fi

if [ "$nag" -eq 0 ]; then
  exit 0
fi

message="Context maintenance: project context ${reason}. Consider running /tidy-context (or the context-gardener skill) this session before it drifts further."

# Minimal JSON string escaping (backslash, double quote) — message is built
# from our own fixed text plus numbers, so this is a safety net, not a real need.
escaped=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$escaped"
exit 0
