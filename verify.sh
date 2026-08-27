#!/bin/sh
# Roadmap-level gate for the /goal run (D-069, D-110). Read-only.
#
# The terminal class of the run is derived here from the run-state store
# (`run/events.jsonl`), the compiled task graph, the per-task evidence and the
# repository itself — never from prose and never from a claim made by an agent.
# The last line is exactly one of:
#
#   status: DONE           every task is done and every integrity check passes
#   status: BLOCKED HUMAN  nothing runnable, nothing active, an open
#                          PREFLIGHT-DEFECTS.md row
#   status: FAILED SYSTEM  an integrity failure: a forged, stale, dirty,
#                          unpushed, unverifiable or store-mismatching state
#   status: PENDING        runnable or active work remains
#
# Every failed check prints one diagnostic line before the verdict.
#
# Usage: sh verify.sh [--root <dir>] [--expect <n>]
#   --root    repository to judge (default: the directory of this script)
#   --expect  the number of task ids the compiler must yield
#
# Exit code: 0 for DONE, 1 for PENDING or BLOCKED HUMAN, 2 for FAILED SYSTEM.
set -u
# Importing the state store must never leave bytecode behind in the tree.
PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

ROOT=""
EXPECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --expect) EXPECT="${2:-}"; shift 2 ;;
    --expect=*) EXPECT="${1#--expect=}"; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ROOT" ] || ROOT="$(dirname "$0")"
cd "$ROOT" || { echo "cannot enter $ROOT"; echo "status: FAILED SYSTEM"; exit 2; }

SYS=0        # integrity failures
DONE_ALL=1   # every task is done
say() { echo "$1"; }
sysfail() { SYS=$((SYS + 1)); say "$1"; }

TMP="$(mktemp -d)" || { echo "mktemp failed"; echo "status: FAILED SYSTEM"; exit 2; }
trap 'rm -rf "$TMP"' EXIT INT TERM

# --------------------------------------------------------------------------
# 1. the compiled task graph
# --------------------------------------------------------------------------
if [ ! -f tools/roadmap_compile.py ] || [ ! -f ROADMAP.md ]; then
  sysfail "compiler input missing: tools/roadmap_compile.py or ROADMAP.md"
  IDS=""
else
  if ! python3 tools/roadmap_compile.py --json ${EXPECT:+--expect "$EXPECT"} ROADMAP.md \
      >"$TMP/dag.json" 2>"$TMP/dag.err"; then
    sysfail "compiler failed: $(head -n 1 "$TMP/dag.err")"
  fi
  IDS=$(python3 -c 'import json,sys
try:
    d, _ = json.JSONDecoder().raw_decode(open(sys.argv[1]).read().lstrip())
except Exception as exc:  # noqa: BLE001 - any decode problem is a failure
    sys.stderr.write(str(exc)); sys.exit(1)
print("\n".join(d["ids"]))' "$TMP/dag.json" 2>/dev/null)
fi
COUNT=$(printf '%s\n' "$IDS" | grep -c . )
[ -n "$IDS" ] || sysfail "no task ids compiled from ROADMAP.md"
if [ -n "$EXPECT" ] && [ "$COUNT" -ne "$EXPECT" ]; then
  sysfail "task count: $COUNT compiled, $EXPECT expected"
fi

# --------------------------------------------------------------------------
# 2. the run-state store: statuses, runnable set, progress rows, projections
# --------------------------------------------------------------------------
if [ ! -f tools/state.py ] || [ ! -f run/events.jsonl ]; then
  sysfail "state store missing: tools/state.py or run/events.jsonl"
  : >"$TMP/state.txt"
else
  if ! python3 tools/state.py verify >"$TMP/chain.out" 2>&1; then
    sysfail "state store: $(tail -n 1 "$TMP/chain.out")"
  fi
  if ! python3 - >"$TMP/state.txt" 2>"$TMP/state.err" <<'PY'
import os, sys, tempfile
sys.path.insert(0, os.path.join(os.getcwd(), "tools"))
import state as S

st = S.project(S.read_events())
for tid in st["order"]:
    print("task %s %s" % (tid, st["tasks"][tid]["status"]))
for tid in S.runnable(st):
    # A `done` row is not runnable; the store's predicate omits that status
    # from its exclusion list, so the gate filters it out here.
    if st["tasks"][tid]["status"] != "done":
        print("runnable %s" % tid)
for row in st["progress"]:
    print("prow %s" % row["task"])

tmp = tempfile.mkdtemp()
want_readme, want_progress = S.README_PATH, S.PROGRESS_PATH
S.README_PATH = os.path.join(tmp, "README.md")
S.PROGRESS_PATH = os.path.join(tmp, "PROGRESS.md")
S.render(st)
for rendered, actual, name in ((S.README_PATH, want_readme, "tasks/README.md"),
                               (S.PROGRESS_PATH, want_progress, "PROGRESS.md")):
    try:
        same = open(rendered, encoding="utf-8").read() == \
            open(actual, encoding="utf-8").read()
    except OSError:
        same = False
    print("projection %s %s" % (name, "ok" if same else "mismatch"))
PY
  then
    sysfail "state store unreadable: $(tail -n 1 "$TMP/state.err")"
  fi
fi

grep '^projection ' "$TMP/state.txt" | while read -r _ name verdict; do
  [ "$verdict" = "ok" ] || echo "projection $name differs from \`state.py render\`"
done >"$TMP/proj.bad"
if [ -s "$TMP/proj.bad" ]; then
  cat "$TMP/proj.bad"
  SYS=$((SYS + 1))
fi

RUNNABLE=$(grep -c '^runnable ' "$TMP/state.txt")
ACTIVE=$(awk '$1=="task" && ($3=="in-progress" || $3=="leased" || $3=="waiting" || $3=="resource-waiting") {n++} END {print n+0}' "$TMP/state.txt")
FAILEDSYS=$(awk '$1=="task" && $3=="failed-system" {n++} END {print n+0}' "$TMP/state.txt")
[ "$FAILEDSYS" -eq 0 ] || sysfail "$FAILEDSYS task(s) in status failed-system"

status_of() { awk -v want="$1" '$1=="task" && $2==want {print $3; exit}' "$TMP/state.txt"; }

# --------------------------------------------------------------------------
# 3. git facts: clean tree, pushed head
# --------------------------------------------------------------------------
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  sysfail "not a git repository: $(pwd)"
  HEAD_SHA=""
  REMOTE_SHA=""
else
  if [ -n "$(git status --porcelain)" ]; then
    sysfail "working tree is dirty: $(git status --porcelain | head -n 1)"
  fi
  HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
  REMOTE_SHA=$(git rev-parse origin/main 2>/dev/null || echo "")
  if [ -z "$REMOTE_SHA" ]; then
    sysfail "no origin/main to compare HEAD against"
  elif [ "$HEAD_SHA" != "$REMOTE_SHA" ]; then
    sysfail "HEAD $HEAD_SHA is not pushed (origin/main is $REMOTE_SHA)"
  fi
fi

# Hash of a task bundle: `tools/bundle.py hash <id>` when that tool exists,
# otherwise the SHA-256 of the three bundle files in a fixed order.
bundle_hash() {
  if [ -f tools/bundle.py ]; then
    python3 tools/bundle.py hash "$1" 2>/dev/null | tr -d ' \t' | tail -n 1
  else
    python3 -c 'import hashlib,sys
h = hashlib.sha256()
for name in ("TASK.md", "task.toml", "verify.sh"):
    with open("tasks/%s/%s" % (sys.argv[1], name), "rb") as fh:
        h.update(fh.read())
print(h.hexdigest())' "$1" 2>/dev/null
  fi
}

# --------------------------------------------------------------------------
# 4. per task: bundle files, and for a done task its evidence
# --------------------------------------------------------------------------
for id in $IDS; do
  dir="tasks/$id"
  for f in TASK.md task.toml verify.sh; do
    [ -f "$dir/$f" ] || sysfail "$id: bundle file $dir/$f is missing"
  done

  st=$(status_of "$id")
  [ -n "$st" ] || sysfail "$id: no row in the run-state store"
  if [ "$st" != "done" ]; then
    DONE_ALL=0
    continue
  fi

  out="$dir/verify.out"
  if [ ! -f "$out" ]; then
    sysfail "$id: done in the store but $out is missing"
    continue
  fi
  last=$(tail -n 1 "$out")
  if [ "$last" != "status: DONE" ]; then
    sysfail "$id: $out does not end \`status: DONE\` (ends \`$last\`)"
    continue
  fi

  sha=$(awk '/^commit: [0-9a-f]{40}$/ {print $2}' "$out" | tail -n 1)
  if [ -z "$sha" ]; then
    sysfail "$id: $out names no \`commit: <40hex>\` line"
  elif [ -n "$REMOTE_SHA" ] && ! git merge-base --is-ancestor "$sha" origin/main 2>/dev/null; then
    sysfail "$id: commit $sha is not an ancestor of the pushed origin/main"
  fi

  recorded=$(awk '/^bundle_hash: / {print $2}' "$out" | tail -n 1)
  current=$(bundle_hash "$id")
  if [ -z "$recorded" ]; then
    sysfail "$id: $out records no bundle_hash, so it cannot be shown fresh"
  elif [ -z "$current" ]; then
    sysfail "$id: the bundle hash of $dir cannot be computed"
  elif [ "$recorded" != "$current" ]; then
    sysfail "$id: $out is stale — bundle_hash $recorded, bundle is now $current"
  fi

  man="$dir/evidence.json"
  if [ ! -f "$man" ]; then
    sysfail "$id: evidence manifest $man is missing"
  elif ! python3 tools/evidence_manifest.py validate "$man" >"$TMP/man.out" 2>&1; then
    sysfail "$id: $man is invalid: $(tail -n 1 "$TMP/man.out")"
  else
    integrated=$(python3 -c 'import json,sys
print(json.load(open(sys.argv[1])).get("integrated_sha", ""))' "$man" 2>/dev/null)
    if [ -n "$sha" ] && [ "$integrated" != "$sha" ]; then
      sysfail "$id: evidence integrated_sha $integrated does not match commit $sha"
    fi
  fi

  if ! sh "$dir/verify.sh" host >"$TMP/re.out" 2>&1; then
    sysfail "$id: re-running $dir/verify.sh host failed: $(tail -n 1 "$TMP/re.out")"
  elif [ "$(tail -n 1 "$TMP/re.out")" != "status: DONE" ]; then
    sysfail "$id: re-running $dir/verify.sh host ends \`$(tail -n 1 "$TMP/re.out")\`"
  fi

  if [ "$(grep -c "^prow $id\$" "$TMP/state.txt")" -ne 1 ]; then
    sysfail "$id: PROGRESS.md must hold exactly one row for a done task"
  fi
done

# --------------------------------------------------------------------------
# 5. open operator defects
# --------------------------------------------------------------------------
OPEN=0
if [ -f PREFLIGHT-DEFECTS.md ]; then
  OPEN=$(awk -F'|' '/^\| *[0-9]+ *\|/ { n = NF - 1; cell = $n; gsub(/[ \t]/, "", cell); if (cell == "") c++ } END {print c+0}' PREFLIGHT-DEFECTS.md)
fi

# --------------------------------------------------------------------------
# 6. verdict
# --------------------------------------------------------------------------
say "tasks: $COUNT compiled, $(awk '$1=="task" && $3=="done" {n++} END {print n+0}' "$TMP/state.txt") done, $RUNNABLE runnable, $ACTIVE active; open defects: $OPEN"

if [ "$SYS" -gt 0 ]; then
  say "status: FAILED SYSTEM"
  exit 2
fi
if [ "$DONE_ALL" -eq 1 ] && [ "$COUNT" -gt 0 ]; then
  say "status: DONE"
  exit 0
fi
if [ "$RUNNABLE" -gt 0 ] || [ "$ACTIVE" -gt 0 ]; then
  say "status: PENDING"
  exit 1
fi
if [ "$OPEN" -gt 0 ]; then
  say "status: BLOCKED HUMAN"
  exit 1
fi
say "no task is runnable or active, none is blocked on an operator input, and work remains"
say "status: FAILED SYSTEM"
exit 2
