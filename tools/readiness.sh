#!/bin/sh
# Readiness gates (D-109).
#
#   sh tools/readiness.sh static   documents, bundles, lock, state - no network
#   sh tools/readiness.sh live     this host: tools, logins, power, permissions
#
# Each mode prints one line per diagnostic, then the lock hash the gate was
# taken against, then a final `status: READY` or `status: NOT READY`. Both
# modes print the same `lock_hash`, so a static pass and a live pass can be
# shown to belong to the same locked plan.
#
# A live check that only a human can repair is printed as
# `blocked-on-human: <PREFLIGHT-DEFECTS.md row>` and still makes the run NOT
# READY: the gate reports what is true, it never lowers the bar.
set -u

CDPATH=''
export CDPATH
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo" || exit 1

mode="${1:-}"
case "$mode" in
  static|live) ;;
  *) echo "usage: sh tools/readiness.sh static|live" >&2; exit 2 ;;
esac

failures=0
blocked=0

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# ok <name> <command...>  - the command must exit 0.
ok() {
  name=$1
  shift
  out=$("$@" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'ok       %-28s %s\n' "$name" "$(printf '%s' "$out" | head -n 1)"
  else
    failures=$((failures + 1))
    printf 'FAIL     %-28s exit %s: %s\n' "$name" "$rc" \
      "$(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')"
  fi
}

# oksh <name> <shell snippet> - the snippet must exit 0.
oksh() {
  name=$1
  shift
  out=$(sh -c "$*" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'ok       %-28s %s\n' "$name" "$(printf '%s' "$out" | head -n 1)"
  else
    failures=$((failures + 1))
    printf 'FAIL     %-28s exit %s: %s\n' "$name" "$rc" \
      "$(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')"
  fi
}

# expect <name> <expected substring> <command...> - output must contain it.
expect() {
  name=$1
  want=$2
  shift 2
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -qF -- "$want"; then
    printf 'ok       %-28s %s\n' "$name" "$want"
  else
    failures=$((failures + 1))
    printf 'FAIL     %-28s expected %s, got: %s\n' "$name" "$want" \
      "$(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"
  fi
}

# human <name> <PREFLIGHT-DEFECTS row> <shell snippet>
# A check whose repair needs a browser login, an OTP, a consent screen, a
# UI-created credential or billing (D-050, D-070, D-076).
human() {
  name=$1
  row=$2
  shift 2
  if sh -c "$*" >/dev/null 2>&1; then
    printf 'ok       %-28s (human-provided input is in place)\n' "$name"
  else
    blocked=$((blocked + 1))
    printf 'blocked-on-human: %s (%s)\n' "$row" "$name"
  fi
}

lock_hash() {
  awk '/^lock_hash[ \t]*=/ {
         gsub(/.*=[ \t]*"/, ""); gsub(/".*/, ""); print; exit
       }' run/LOCK.toml
}

# ---------------------------------------------------------------------------
# static gate
# ---------------------------------------------------------------------------

static_gate() {
  echo "readiness: static gate (D-109)"
  echo

  expect "roadmap compile" \
    "81 tasks, 0 cycles, 0 unproduced artifacts, 0 prose gates" \
    python3 tools/roadmap_compile.py
  expect "roadmap bundles" "81/81 bundles valid" \
    python3 tools/roadmap_compile.py --bundles
  ok     "bundle verify"      python3 tools/bundle.py verify --all
  ok     "lock check"         python3 tools/lock.py check
  ok     "finding disposition" python3 tools/check_disposition.py
  ok     "gate fixtures"      sh tools/gate_fixtures.sh
  # A generated task verifier must actually pass its own host part, or wave 0
  # cannot start: M1-01 is the seeding task and stands for the generator.
  oksh   "M1-01 self-verify" \
    "test \"\$(sh tasks/M1-01/verify.sh host 2>&1 | tail -1)\" = 'status: DONE'"
  oksh   "shellcheck"         "shellcheck -s sh verify.sh tools/*.sh tasks/*/verify.sh"
  # Row 4.5: no task verifier is interactive, mutating or transient.
  oksh   "verifiers durable" \
    "test -z \"\$(grep -lE 'hardline|herdr session attach|--latest|newest' tasks/*/verify.sh)\""
  ok     "invariant lint"     python3 tools/invariant_lint.py
  ok     "run store verify"   python3 tools/state.py verify
}

# ---------------------------------------------------------------------------
# live gate
# ---------------------------------------------------------------------------

live_gate() {
  echo "readiness: live host gate (goal/PREFLIGHT.md §1)"
  echo

  ok   "docker"          docker info
  expect "herdr"          "herdr 0.8.2" herdr --version
  ok   "dash"            dash -c 'echo ok'
  ok   "shellcheck"      shellcheck --version
  ok   "gitleaks"        gitleaks version
  ok   "claude"          claude --version
  ok   "codex"           codex --version
  ok   "mise"            mise --version
  # The jackin DCO hook signs off every agent commit (R3-75). jackin itself is
  # built by M1-02, so an absent binary is informational, not a failure; once it
  # is installed, `dco = true` in its config is required.
  oksh "jackin dco" \
    "cfg=\${JACKIN_CONFIG_DIR:-\$HOME/.config/jackin}/config.toml; \
     command -v jackin >/dev/null 2>&1 || { echo 'pending: M1-02 (jackin not installed yet)'; exit 0; }; \
     grep -q 'dco = true' \"\$cfg\""
  # Account metadata proves the CLI is installed and wired to a tenant; the
  # harmless read below separately proves the desktop session is unlocked.
  oksh "op configured"   "op account list </dev/null | grep -q ."
  # The launcher is a shell function, so it only exists in an interactive zsh.
  oksh "claude-yolo"     "zsh -ic 'type claude-yolo' >/dev/null"
  # The host must stay awake for the whole run.
  oksh "caffeinate"      "pgrep -x caffeinate >/dev/null"
  # Unset or 0 both mean the screen saver never starts.
  oksh "screensaver off" \
    "v=\$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null); \
     test -z \"\$v\" || test \"\$v\" = 0"
  # Claude Code must resume by itself when the usage limit resets.
  oksh "auto-continue"   "test \"\$(jq -r .autoContinueAtUsageLimit ~/.claude/settings.json)\" = true"
  # Readiness never launches an agent. The operator starts the interactive
  # coordinator only after this gate reports READY.
  oksh "coordinator yolo flags" \
    "grep -q -- '--dangerously-skip-permissions' tools/supervisor.sh && \
     grep -q -- 'skipDangerousModePermissionPrompt' tools/supervisor.sh"

  # Human-only inputs. Each one is a browser login, an OTP, a consent screen,
  # a UI-created credential or a repository setting only the owner can flip.
  # Signed-in proof (PREFLIGHT-DEFECTS row 4). A configured account is checked
  # live above; prove the unlocked desktop integration with a harmless read.
  human "1Password signed in" "PREFLIGHT-DEFECTS: op-signin" \
    "op read 'op://Private/Context7/API Keys/Claude' </dev/null >/dev/null"
  human "operator service account" "PREFLIGHT-DEFECTS #7: M1-05d operator-service-account" \
    "op read 'op://tailrocks/op-service-account-jackin-operator/credential' </dev/null | grep -q ."
  human "gh auth" "PREFLIGHT-DEFECTS: gh-auth" \
    "gh auth status"
  human "operator browser profile" "PREFLIGHT-DEFECTS: browser-profile" \
    "test -s \"\$HOME/.jackin/agent-browser-profile/state.json\""
  human "GitHub App jackin-daemon" "PREFLIGHT-DEFECTS: github-app" \
    "gh api /orgs/jackin-project/installations --jq '.installations[].app_slug' 2>/dev/null | grep -qx jackin-daemon"
  human "delete_branch_on_merge off" "PREFLIGHT-DEFECTS: delete-branch-on-merge" \
    "for r in jackin-project/jackin jackin-project/jackin-the-architect tailrocks/termrock; do \
       gh api repos/\$r --jq .delete_branch_on_merge 2>/dev/null | grep -qx false || exit 1; \
     done"
  human "the-architect ruleset" "PREFLIGHT-DEFECTS: protect-main-ruleset" \
    "gh api repos/jackin-project/jackin-the-architect/rulesets --jq '.[].name' 2>/dev/null | grep -q protect-main"
  human "pinned role refs" "PREFLIGHT-DEFECTS: pinned-role-tags" \
    "gh api repos/tailrocks/tailrocks-skills >/dev/null 2>&1"
}

case "$mode" in
  static) static_gate ;;
  live)   live_gate ;;
esac

echo
hash=$(lock_hash)
if [ -z "$hash" ]; then
  echo "FAIL     lock_hash                    run/LOCK.toml has no [run].lock_hash"
  failures=$((failures + 1))
  hash="(missing)"
fi
echo "lock_hash: $hash"

if [ "$blocked" -gt 0 ]; then
  echo "blocked-on-human: $blocked item(s) above need the operator"
fi

if [ "$failures" -eq 0 ] && [ "$blocked" -eq 0 ]; then
  echo "next command (run manually): sh tools/supervisor.sh start"
  echo "status: READY"
  exit 0
fi
echo "status: NOT READY"
exit 1
