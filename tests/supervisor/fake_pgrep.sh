#!/bin/sh
# Emit the calling supervisor subshell as a false `claude` match. A safe
# quiescence scan must discard its own process tree before cwd inspection.
set -eu
[ "${1:-}" = "-x" ] && [ "${2:-}" = "claude" ] || exit 2
printf '%s\n' "$PPID"
