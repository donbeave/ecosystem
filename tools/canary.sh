#!/bin/sh
# End-to-end canary for the managed run (readiness plan Phase 3, row 3.1).
#
# A synthetic task, CANARY-01, is carried through the whole delivery path with
# the real tools and against this repository: a content-addressed bundle, a
# lease with a fencing token, an isolated worktree and branch, a worker commit,
# one pull request, an independent verification at the pull-request head, an
# integrator merge, an evidence manifest naming the integrated commit, and a
# `done` transition. The task is outside M1..M12, so the compiler still yields
# 81 tasks and the roadmap gate ignores it.
#
# The run-state store is a copy of `run/events.jsonl` under a temporary
# directory (`ECOSYSTEM_STORE`), so the rehearsal never writes the run of
# record. Everything else -- git, gh, the bundle hasher, the evidence manifest
# -- is real.
#
# Linear is not touched: 1Password is not signed in, so the Linear credential
# is unavailable and the external object id records that as blocked on the
# human (PREFLIGHT-DEFECTS.md row 4).
#
# Usage: sh tools/canary.sh <run-id>
set -eu

RUN_ID="${1:-}"
if [ -z "$RUN_ID" ]; then
  echo "usage: sh tools/canary.sh <run-id>" >&2
  exit 2
fi

unset CDPATH
REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO"

TASK=CANARY-01
DIR="tasks/$TASK"
BRANCH="managed/$RUN_ID/$TASK"
WANT="canary $TASK $RUN_ID"

TMP=$(mktemp -d) || { echo "mktemp failed" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT INT TERM

step() { printf '\n== %s\n' "$1"; }

# --------------------------------------------------------------------------
# 1. the task bundle, content addressed
# --------------------------------------------------------------------------
step "bundle"
mkdir -p "$DIR"

cat >"$DIR/TASK.md" <<EOF
# $TASK — canary

Synthetic task used to rehearse the delivery path end to end. It belongs to no
milestone and to no roadmap row, so the compiler must keep yielding 81 tasks
and the roadmap gate must ignore this id.

## What the worker does

Write the file \`$DIR/canary.txt\` containing exactly the line below, commit it
with a sign-off on the task branch, push that branch, and open one pull request
against the integration branch.

    $WANT

## What proves it

\`sh $DIR/verify.sh host\` checks the file and its content at the commit under
verification and prints \`status: DONE\` as its last line. The evidence manifest
names the integrated commit and the external objects the task created.
EOF

cat >"$DIR/task.toml" <<EOF
# Synthetic canary task (readiness plan Phase 3). Written by tools/canary.sh,
# not by tools/bundle.py: it has no ROADMAP.md row on purpose.
id = "$TASK"
milestone = "CANARY"
title = "Rehearse the delivery path end to end"
repo = "donbeave/ecosystem"
repos = [
  "ecosystem",
]
branch = "$BRANCH"
base = "main"
role = "host"
runtime = "host"
lane = "L0"
delivery = "canary"
size = "S"
depends_on = []

[limits]
attempts = 1

[verify]
script = "verify.sh"
has_container_part = false
container = []
host = [
  "sh $DIR/verify.sh host",
]
EOF

cat >"$DIR/expected-evidence.toml" <<EOF
# Evidence this task must produce, declared before it runs (D-118).
task = "$TASK"

[[artefact]]
path = "canary.txt"
marker = "$WANT"

[[artefact]]
path = "evidence.json"
marker = "integrated_sha"

[[artefact]]
path = "verify.out"
marker = "status: DONE"
EOF

cat >"$DIR/verify.sh" <<EOF
#!/bin/sh
# $TASK verification. Written by tools/canary.sh.
#
# Takes one argument, container or host, and runs only that part. Prints
# status: DONE as its last line on success and status: PENDING otherwise.
# Paths are resolved from the script itself, so the check is the same in an
# isolated worktree, at the pull-request head, and on the integration branch.
set -u

role="\${1:-host}"
if [ "\$role" = "container" ]; then
  echo "no container part"
  echo "status: DONE"
  exit 0
fi

unset CDPATH
dir=\$(cd -- "\$(dirname -- "\$0")" && pwd)
file="\$dir/canary.txt"
want="$WANT"

if [ ! -f "\$file" ]; then
  echo "missing: \$file"
  echo "status: PENDING"
  exit 1
fi

got=\$(cat "\$file")
if [ "\$got" != "\$want" ]; then
  echo "content differs: expected \\"\$want\\", found \\"\$got\\""
  echo "status: PENDING"
  exit 1
fi

echo "canary file present with the expected content"
echo "status: DONE"
EOF
chmod 755 "$DIR/verify.sh"

python3 tools/bundle.py hash --extra "$TASK" >"$TMP/hash.out"
BUNDLE_HASH=$(awk '{print $NF}' "$TMP/hash.out")
case "$BUNDLE_HASH" in
  [0-9a-f]*) ;;
  *) echo "the bundle hash could not be computed" >&2; exit 1 ;;
esac
echo "bundle_hash: $BUNDLE_HASH"

# --------------------------------------------------------------------------
# 2. the run-state store: a copy, then register, arm and lease
# --------------------------------------------------------------------------
step "state store"
STORE="$TMP/store"
mkdir -p "$STORE"
cp run/events.jsonl "$STORE/events.jsonl"
ECOSYSTEM_STORE="$STORE"
export ECOSYSTEM_STORE

cat >"$TMP/dag.json" <<EOF
{"ids": ["$TASK"], "edges": [], "waves": {"$TASK": 0}}
EOF
python3 tools/state.py init --dag "$TMP/dag.json" --run-id "$RUN_ID"
python3 tools/state.py transition "$TASK" ready --result "armed"

token_of() { python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'; }
WORKER_TOKEN=$(python3 tools/state.py lease "$TASK" --owner "worker:ecosystem" \
  --ttl 3600 | token_of)
echo "worker fencing token: $WORKER_TOKEN"
python3 tools/state.py transition "$TASK" in-progress --token "$WORKER_TOKEN" \
  --lane L0 --path "$BRANCH"

idem() {
  python3 -c 'import os,sys
sys.path.insert(0, os.path.join(os.getcwd(), "tools"))
import state
print(state.idempotency_key(sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]))' \
    "$RUN_ID" "$TASK" 1 "$1"
}

# --------------------------------------------------------------------------
# 3. worktree, worker commit, task branch, one pull request
# --------------------------------------------------------------------------
step "worktree and worker"
git fetch origin main >/dev/null 2>&1
BASE=$(git rev-parse origin/main)
echo "base: $BASE"

# The branch and the worktree are created once; a second run of the canary
# reuses the branch it already pushed rather than opening a second one.
WT="$TMP/wt"
git fetch -q origin "$BRANCH" 2>/dev/null || true
if git rev-parse --verify -q "refs/remotes/origin/$BRANCH" >/dev/null; then
  echo "branch $BRANCH already exists on the remote; reusing it"
  git worktree add -q --detach "$WT" "origin/$BRANCH"
else
  git worktree add -b "$BRANCH" "$WT" "$BASE" >/dev/null
fi
mkdir -p "$WT/$DIR"
cp "$DIR/TASK.md" "$DIR/task.toml" "$DIR/expected-evidence.toml" \
  "$DIR/verify.sh" "$WT/$DIR/"
chmod 755 "$WT/$DIR/verify.sh"
printf '%s\n' "$WANT" >"$WT/$DIR/canary.txt"

git -C "$WT" add "$DIR"
if [ -n "$(git -C "$WT" status --porcelain)" ]; then
  git -C "$WT" commit -s -q -m "canary: add the $TASK bundle and its canary file

Synthetic task for the readiness canary. It has no roadmap row, so the
compiler still yields 81 tasks and the roadmap gate ignores this id."
  git -C "$WT" push -q -u origin "HEAD:$BRANCH"
else
  echo "the task branch already carries the canary commit"
fi
WORKER_SHA=$(git -C "$WT" rev-parse HEAD)
echo "worker commit: $WORKER_SHA"
python3 tools/state.py event "$TASK" --operation "push" --attempt 1 \
  --token "$WORKER_TOKEN" --result "$WORKER_SHA" --key "$(idem push)"

step "pull request"
PR_KEY=$(idem github_pr)
PR_NUM=$(gh pr list --head "$BRANCH" --state all --json number \
  --jq '.[0].number // empty')
if [ -z "$PR_NUM" ]; then
  gh pr create --base main --head "$BRANCH" \
    --title "canary: $TASK $RUN_ID" \
    --body "Readiness canary for the managed run. The synthetic task $TASK
carries a bundle and one canary file through the whole delivery path: an
isolated worktree and branch, a worker commit, this pull request, an
independent verification at the pull-request head, and an integrator merge.

The task has no roadmap row, so the compiler still yields 81 tasks and the
roadmap gate ignores this id.

Run: $RUN_ID
Idempotency key: $PR_KEY" >"$TMP/pr.out"
  PR_NUM=$(gh pr list --head "$BRANCH" --state all --json number \
    --jq '.[0].number // empty')
else
  echo "pull request already open for $BRANCH; not creating a second one"
fi
PR_URL=$(gh pr view "$PR_NUM" --json url --jq .url)
echo "pull request: $PR_URL"
python3 tools/state.py event "$TASK" --operation "github_pr" --attempt 1 \
  --token "$WORKER_TOKEN" --result "$PR_URL" --key "$PR_KEY" || true

# --------------------------------------------------------------------------
# 4. independent verification, at the pull-request head
# --------------------------------------------------------------------------
step "independent verification"
python3 tools/state.py release "$TASK" --token "$WORKER_TOKEN"
PR_HEAD=$(gh pr view "$PR_NUM" --json headRefOid --jq .headRefOid)
echo "pull request head: $PR_HEAD"
VWT="$TMP/verify-wt"
git fetch -q origin "$BRANCH"
git worktree add -q --detach "$VWT" "$PR_HEAD"
( cd "$VWT" && sh "$DIR/verify.sh" host ) >"$TMP/verifier.out" 2>&1
cat "$TMP/verifier.out"
[ "$(tail -n 1 "$TMP/verifier.out")" = "status: DONE" ] || {
  echo "the independent verifier did not end \`status: DONE\`" >&2
  exit 1
}

# --------------------------------------------------------------------------
# 5. the integrator merges, holding its own lease
# --------------------------------------------------------------------------
step "integration"
INT_TOKEN=$(python3 tools/state.py lease "$TASK" --owner "integrator:ecosystem" \
  --ttl 1800 | token_of)
echo "integrator fencing token: $INT_TOKEN"
MERGE_KEY=$(idem github_merge)
STATE=$(gh pr view "$PR_NUM" --json state --jq .state)
if [ "$STATE" = "OPEN" ]; then
  gh pr merge "$PR_NUM" --merge --delete-branch=false
else
  echo "pull request already $STATE; not merging again"
fi
git fetch -q origin main
INTEGRATED=$(git rev-parse origin/main)
echo "integrated: $INTEGRATED"
python3 tools/state.py event "$TASK" --operation "github_merge" --attempt 1 \
  --token "$INT_TOKEN" --result "$INTEGRATED" --key "$MERGE_KEY" || true

# Bring the integration branch into the working tree so the evidence is
# recorded against the merged content. A fast-forward is the normal case; a
# local commit that is not yet pushed makes it a rebase.
if ! git merge --ff-only origin/main >/dev/null 2>&1; then
  git rebase origin/main >/dev/null
fi
# Take the bundle from the integration branch, so the evidence is recorded
# against the merged content rather than against the local copies this script
# wrote before the pull request.
git checkout -q origin/main -- "$DIR"
[ -f "$DIR/canary.txt" ] || { echo "the merge did not deliver $DIR/canary.txt" >&2; exit 1; }
cp "$TMP/verifier.out" "$DIR/verifier.out"

# --------------------------------------------------------------------------
# 6. evidence manifest, `done`, and the filed verify output
# --------------------------------------------------------------------------
step "evidence"
python3 tools/evidence_manifest.py run --task "$TASK" \
  --bundle-hash "$BUNDLE_HASH" --integrated-sha "$INTEGRATED" \
  --dir "$DIR" --attempt 1 --epoch "$INT_TOKEN" \
  --fencing-token "$INT_TOKEN" --result-class DONE \
  --external "github_pr=$PR_URL" \
  --external "linear_issue=blocked-on-human: PREFLIGHT-DEFECTS #4" \
  -- sh "$DIR/verify.sh" host
python3 tools/evidence_manifest.py validate "$DIR/evidence.json"

python3 tools/state.py transition "$TASK" "done" --token "$INT_TOKEN" \
  --lane L0 --path "$BRANCH" --result "canary merged" \
  --evidence "$DIR/evidence.json"
python3 tools/state.py release "$TASK" --token "$INT_TOKEN"
cp "$STORE/events.jsonl" "$DIR/store-events.log"

{
  echo "$TASK canary, run $RUN_ID"
  echo "base: $BASE"
  echo "branch: $BRANCH"
  echo "worker_commit: $WORKER_SHA"
  echo "pull_request: $PR_URL"
  echo "pull_request_head: $PR_HEAD"
  echo "verified_at_head: yes"
  echo "linear_issue: blocked-on-human: PREFLIGHT-DEFECTS #4"
  echo "commit: $INTEGRATED"
  echo "bundle_hash: $BUNDLE_HASH"
  echo "status: DONE"
} >"$DIR/verify.out"
cat "$DIR/verify.out"

git worktree remove --force "$WT" >/dev/null 2>&1 || true
git worktree remove --force "$VWT" >/dev/null 2>&1 || true
