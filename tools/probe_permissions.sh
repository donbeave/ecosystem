#!/bin/sh
# Proves the pinned permission mode performs a normally-prompting operation
# without prompting (readiness row 4.10, D-120). Exit 0 = no prompt, the
# file the agent was asked to create exists.
set -eu

probe_dir="${TMPDIR:-/tmp}"
probe_file="$probe_dir/jackin-permission-probe.$$"
rm -f "$probe_file"

timeout_bin=""
if command -v timeout >/dev/null 2>&1; then
  timeout_bin="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  timeout_bin="gtimeout"
fi

set +e
if [ -n "$timeout_bin" ]; then
  "$timeout_bin" 120 command claude --dangerously-skip-permissions \
    --settings '{"skipDangerousModePermissionPrompt":true}' \
    -p "create the file $probe_file with the Bash tool and reply DONE" \
    --max-turns 3 </dev/null
else
  command claude --dangerously-skip-permissions \
    --settings '{"skipDangerousModePermissionPrompt":true}' \
    -p "create the file $probe_file with the Bash tool and reply DONE" \
    --max-turns 3 </dev/null
fi
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "probe: claude exited $rc (124 = timed out, i.e. it prompted or hung)"
  rm -f "$probe_file"
  exit 1
fi

if [ -f "$probe_file" ]; then
  echo "probe: OK - $probe_file was created without a permission prompt"
  rm -f "$probe_file"
  exit 0
fi

echo "probe: FAIL - $probe_file was not created"
exit 1
