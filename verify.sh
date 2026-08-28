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
# Evidence of a done task names two commits (D-112): the `commit:` line of
# `tasks/<id>/verify.out` is the commit of this repository the evidence was
# recorded against and must be an ancestor of the pushed `origin/main`, and
# `integrated_sha` is the commit the verification ran against. At final-gate
# time it may be behind a later integration head, but must remain its ancestor.
# They are the
# same commit for a task whose `repos` names no involved Git repository
# (host and service labels are not repositories); a task that touches one
# carries its integration target in an `integrated_sha: <40hex>` line,
# which is what its `evidence.json` must match.
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

# The repository names of a task, one per line, read from `repos` in its
# `task.toml` (inline or multi-line array). An absent key prints nothing.
task_repos() {
  [ -f "$1" ] || return 0
  awk '
    /^[ \t]*repos[ \t]*=/ { collect = 1 }
    collect { buf = buf $0; if (index($0, "]")) { collect = 0 } }
    END {
      n = split(buf, part, "\"")
      for (i = 2; i <= n; i += 2) if (part[i] != "") print part[i]
    }' "$1"
}

# Every involved Git repository named by a task, as
# `<owner/name><TAB><integration-branch>`. Product/service labels are
# intentionally absent: Linear, GitHub and 1Password are external systems,
# not repositories whose Git head can bind `integrated_sha`.
task_involved_repositories() {
  task_repos "$1" | while IFS= read -r label; do
    case "$label" in
      jackin)
        printf 'jackin-project/jackin\tfeat/managed-execution\n' ;;
      termrock)
        printf 'tailrocks/termrock\tfeat/managed-execution\n' ;;
      jackin-the-architect)
        printf 'jackin-project/jackin-the-architect\tfeat/managed-execution\n' ;;
      jackin-role-template|jackin-role-template\ \(new\))
        printf 'donbeave/jackin-role-template\tmain\n' ;;
      jackin-crew-builder|jackin-crew-builder\ \(new\))
        printf 'donbeave/jackin-crew-builder\tmain\n' ;;
      jackin-crew-operator|jackin-crew-operator\ \(new\))
        printf 'donbeave/jackin-crew-operator\tmain\n' ;;
      jackin-crew-reviewer|jackin-crew-reviewer\ \(new\))
        printf 'donbeave/jackin-crew-reviewer\tmain\n' ;;
      "role repositories")
        printf 'donbeave/jackin-crew-builder\tmain\n'
        printf 'donbeave/jackin-crew-operator\tmain\n'
        printf 'donbeave/jackin-crew-reviewer\tmain\n' ;;
    esac
  done | awk -F'\t' '!seen[$1]++'
}

# Per-repository records from evidence.json, one tab-separated row each:
# repository, branch, integrated SHA, checkout. Manifest validation rejects
# tabs/newlines in these fields before this representation is consumed.
manifest_repositories() {
  python3 -c 'import json,sys
for row in json.load(open(sys.argv[1])).get("repositories", []):
    print("\t".join(row[key] for key in ("repo", "branch", "integrated_sha", "checkout")))' "$1"
}

verify_repository_head() {
  # $1 task id, $2 repo, $3 branch, $4 SHA, $5 checkout.
  if [ -z "$5" ]; then
    sysfail "$1: $2 evidence has no checkout for ancestry verification"
  elif ! git -C "$5" rev-parse --git-dir >/dev/null 2>&1; then
    sysfail "$1: checkout $5 is not a Git repository"
  else
    origin_url=$(git -C "$5" remote get-url origin 2>/dev/null || true)
    case "$origin_url" in
      */"$2"|*/"$2".git|*:"$2"|*:"$2".git) ;;
      *)
        sysfail "$1: checkout $5 origin is not $2"
        return
        ;;
    esac
    current_head=$(git -C "$5" rev-parse --verify "refs/remotes/origin/$3^{commit}" 2>/dev/null || true)
    if [ -z "$current_head" ]; then
      sysfail "$1: $5 has no pushed origin/$3 integration target for $2"
    elif ! git -C "$5" rev-parse --verify "$4^{commit}" >/dev/null 2>&1; then
      sysfail "$1: integrated_sha $4 does not exist in $2 checkout $5"
    elif ! git -C "$5" merge-base --is-ancestor "$4" "$current_head" 2>/dev/null; then
      sysfail "$1: integrated_sha $4 is not an ancestor of $2 $3 head $current_head"
    fi
  fi
}

# Hash of a task bundle: `tools/bundle.py hash <id>` when that tool exists,
# otherwise the SHA-256 of the three bundle files in a fixed order.
bundle_hash() {
  if [ -f tools/bundle.py ]; then
    # `bundle.py hash <id>` prints "<id> <hash>"; take the hash field.
    python3 tools/bundle.py hash "$1" 2>/dev/null | tail -n 1 | awk '{print $NF}'
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

  # A task with only ecosystem/host/service labels is local to this repository
  # and binds to its ecosystem commit. Repository tasks retain the legacy
  # scalar as the first repository's SHA; the manifest below carries one
  # independently checked record per involved repository.
  involved=$(task_involved_repositories "$dir/task.toml")
  if [ -z "$involved" ]; then
    want_integrated="$sha"
  else
    want_integrated=$(awk '/^integrated_sha: [0-9a-f]{40}$/ {print $2}' "$out" | tail -n 1)
    if [ -z "$want_integrated" ]; then
      sysfail "$id: touches an involved repository but $out names no \`integrated_sha: <40hex>\` line"
    fi
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
    if [ -n "$want_integrated" ] && [ "$integrated" != "$want_integrated" ]; then
      sysfail "$id: evidence integrated_sha $integrated does not match $want_integrated"
    fi

    expected_repos="$TMP/$id.repos.expected"
    actual_repos="$TMP/$id.repos.actual"
    printf '%s\n' "$involved" | sed '/^$/d' >"$expected_repos"
    if ! manifest_repositories "$man" >"$actual_repos" 2>"$TMP/repos.err"; then
      sysfail "$id: cannot read repository evidence: $(tail -n 1 "$TMP/repos.err")"
      : >"$actual_repos"
    fi
    expected_count=$(awk 'END {print NR+0}' "$expected_repos")
    actual_count=$(awk 'END {print NR+0}' "$actual_repos")

    # Old single-repository evidence used checkout.txt plus scalar
    # integrated_sha. Keep accepting that shape; multiple repositories must
    # carry the explicit per-repository array so no repository can hide behind
    # another repository's valid commit.
    if [ "$expected_count" -eq 0 ]; then
      [ "$actual_count" -eq 0 ] || \
        sysfail "$id: manifest names repositories but task.toml names none involved"
    elif [ "$actual_count" -eq 0 ] && [ "$expected_count" -eq 1 ]; then
      IFS="$(printf '\t')" read -r expected_repo expected_branch <"$expected_repos"
      checkout=""
      [ ! -f "$dir/checkout.txt" ] || checkout=$(tail -n 1 "$dir/checkout.txt")
      verify_repository_head "$id" "$expected_repo" "$expected_branch" \
        "$want_integrated" "$checkout"
    elif [ "$actual_count" -ne "$expected_count" ]; then
      sysfail "$id: manifest has $actual_count repository record(s), task requires $expected_count"
    else
      first_expected=$(awk -F'\t' 'NR == 1 {print $1}' "$expected_repos")
      first_actual=$(awk -F'\t' 'NR == 1 {print $1}' "$actual_repos")
      if [ "$first_actual" != "$first_expected" ]; then
        sysfail "$id: first repository record $first_actual must be $first_expected"
      fi
      while IFS="$(printf '\t')" read -r expected_repo expected_branch; do
        matches=$(awk -F'\t' -v repo="$expected_repo" '$1 == repo {n++} END {print n+0}' "$actual_repos")
        if [ "$matches" -ne 1 ]; then
          sysfail "$id: manifest must name $expected_repo exactly once"
          continue
        fi
        actual_record=$(awk -F'\t' -v repo="$expected_repo" '$1 == repo {print; exit}' "$actual_repos")
        IFS="$(printf '\t')" read -r actual_repo actual_branch actual_sha actual_checkout <<EOF_REPO
$actual_record
EOF_REPO
        if [ "$actual_branch" != "$expected_branch" ]; then
          sysfail "$id: $actual_repo branch $actual_branch must be $expected_branch"
          continue
        fi
        verify_repository_head "$id" "$actual_repo" "$actual_branch" \
          "$actual_sha" "$actual_checkout"
      done <"$expected_repos"
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
