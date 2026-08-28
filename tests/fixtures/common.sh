# Shared builder for the gate fixtures (D-069, D-110). Sourced, not executed.
#
# `build_base <dir>` creates a self-contained git repository in <dir> with a
# bare "origin", a three-task fixture roadmap, the real state store and
# manifest tools, and one done task bundle per id, all committed and pushed.
# The result is the `good` fixture; every other fixture is that repository
# with exactly one property broken.

FIXTURE_TOOLS="roadmap_compile.py state.py evidence_manifest.py"
FIXTURE_IDS="M1-01 M1-02 M1-03"

fixture_repo_root() {
  # The repository this fixture tree lives in.
  (cd "$(dirname "$0")/../../.." && pwd)
}

write_roadmap() {
  cat >"$1/ROADMAP.md" <<'MD'
# Fixture roadmap

Three tasks, no dependencies between the last two, one edge M1-01 -> M1-02.

| id | title | scope | repos | depends_on | role | lane | delivery | size | verify | proof |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| M1-01 | First step | fixture | ecosystem | — | builder | L1 | host | S | `sh tasks/M1-01/verify.sh host` | verify.out |
| M1-02 | Second step | fixture | ecosystem | M1-01 | builder | L1 | host | S | `sh tasks/M1-02/verify.sh host` | verify.out |
| M1-03 | Third step | fixture | ecosystem | M1-01 | builder | L1 | host | S | `sh tasks/M1-03/verify.sh host` | verify.out |
MD
}

write_bundles() {
  root="$1"
  for id in $FIXTURE_IDS; do
    mkdir -p "$root/tasks/$id"
    printf '# %s\n\nFixture task.\n' "$id" >"$root/tasks/$id/TASK.md"
    printf 'id = "%s"\nlane = "L1"\npath = "host"\n' "$id" >"$root/tasks/$id/task.toml"
    cat >"$root/tasks/$id/verify.sh" <<'SH'
#!/bin/sh
set -u
echo "side: ${1:-host}"
echo "status: DONE"
SH
    chmod +x "$root/tasks/$id/verify.sh"
  done
}

write_bundle_tool() {
  cat >"$1/tools/bundle.py" <<'PY'
#!/usr/bin/env python3
"""Fixture stand-in for tools/bundle.py: `bundle.py hash <task-id>` prints the
task id and the SHA-256 of its three bundle files, in a fixed order."""
import hashlib
import sys

if len(sys.argv) != 3 or sys.argv[1] != "hash":
    sys.stderr.write("usage: bundle.py hash <task-id>\n")
    raise SystemExit(2)

digest = hashlib.sha256()
for name in ("TASK.md", "task.toml", "verify.sh"):
    with open("tasks/%s/%s" % (sys.argv[2], name), "rb") as handle:
        digest.update(handle.read())
print("%s %s" % (sys.argv[2], digest.hexdigest()))
PY
}

write_defects() {
  cat >"$1/PREFLIGHT-DEFECTS.md" <<'MD'
# Preflight defects

| # | Task | Missing item | Proof it is in place | Recorded (UTC) | Resolved (UTC) |
| --- | --- | --- | --- | --- | --- |
MD
}

write_fixture_lock() {
  root="$1"
  python3 - "$root/run/LOCK.toml" <<'PY'
import hashlib
import pathlib
import sys

body = "[run]\nepoch = 1\n"
digest = hashlib.sha256(body.encode("utf-8")).hexdigest()
pathlib.Path(sys.argv[1]).write_text(
    body + 'lock_hash = "%s"\n' % digest,
    encoding="utf-8",
)
print(digest)
PY
}

fixture_transition() {
  root="$1"
  id="$2"
  target="$3"
  [ "$target" = "ready" ] && return 0
  lease="$(cd "$root" && python3 tools/state.py lease "$id" \
    --owner "fixture:$id" --ttl 600)"
  token="$(printf '%s\n' "$lease" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"
  # Only a task left `done` gets a `verify.out` written for it, so only a
  # `done` transition may name one: a ledger row that cites evidence the
  # fixture never wrote is a dangling claim, which is exactly what the gate
  # exists to reject.
  if [ "$target" = "done" ]; then
    ( cd "$root" && python3 tools/state.py transition "$id" in-progress \
      --token "$token" --lane L1 --path host >/dev/null )
    ( cd "$root" && python3 tools/state.py transition "$id" "$target" \
      --token "$token" --lane L1 --path host --result fixture \
      --evidence "tasks/$id/verify.out" >/dev/null )
  else
    ( cd "$root" && python3 tools/state.py transition "$id" "$target" \
      --token "$token" --lane L1 --path host --result fixture >/dev/null )
  fi
  ( cd "$root" && python3 tools/state.py release "$id" --token "$token" >/dev/null )
}

# build_base <dir> [status-of-last-task]
# The third task is left in the given status (default `done`).
build_base() {
  root="$1"
  last_status="${2:-done}"
  src="$(fixture_repo_root)"

  mkdir -p "$root/tools" "$root/run"
  for tool in $FIXTURE_TOOLS; do
    cp "$src/tools/$tool" "$root/tools/$tool"
  done
  write_bundle_tool "$root"
  write_roadmap "$root"
  write_bundles "$root"
  write_defects "$root"
  cp "$src/verify.sh" "$root/verify.sh"

  git init -q "$root"
  git -C "$root" symbolic-ref HEAD refs/heads/main
  git -C "$root" config user.email fixture@example.invalid
  git -C "$root" config user.name Fixture
  git init -q --bare "$root.origin.git"
  git -C "$root" remote add origin "$root.origin.git"

  # Seed the state store from the compiled fixture graph, then move every task
  # to its fixture status. Bind the store to the fixture's own verified lock,
  # matching the production invariant rather than bypassing lock validation.
  ( cd "$root" && python3 tools/roadmap_compile.py --json --expect 3 ROADMAP.md >run/dag.json 2>/dev/null )
  ( cd "$root" && python3 tools/state.py init --dag run/dag.json --run-id fixture >/dev/null )
  fixture_lock_hash="$(write_fixture_lock "$root")"
  ( cd "$root" && python3 tools/state.py lock-epoch --epoch 1 \
      --lock-hash "$fixture_lock_hash" --key fixture-lock-epoch-1 \
      --bootstrap >/dev/null )
  ( cd "$root" && python3 tools/state.py arm >/dev/null )
  for id in M1-01 M1-02; do
    fixture_transition "$root" "$id" 'done'
  done
  fixture_transition "$root" M1-03 "$last_status"

  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: bundles, tools, state store"
  sha="$(git -C "$root" rev-parse HEAD)"

  # Evidence names the commit it was produced against, so it is written after
  # that commit exists and committed on top of it.
  for id in $FIXTURE_IDS; do
    [ "$id" = "M1-03" ] && [ "$last_status" != "done" ] && continue
    write_evidence "$root" "$id" "$sha"
  done
  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: task evidence"
  git -C "$root" push -q origin main
  git -C "$root" fetch -q origin
}

# write_evidence <root> <id> <sha>
write_evidence() {
  root="$1"; id="$2"; sha="$3"
  hash="$( cd "$root" && python3 tools/bundle.py hash "$id" | awk '{print $NF}' )"
  cat >"$root/tasks/$id/verify.out" <<EOF
task: $id
side: host
commit: $sha
bundle_hash: $hash
status: DONE
EOF
  ( cd "$root" && python3 tools/evidence_manifest.py run --task "$id" \
      --dir "tasks/$id" --bundle-hash "$hash" --integrated-sha "$sha" \
      --result-class DONE -- sh -c 'echo fixture' >/dev/null 2>&1 ) || \
  write_manifest_fallback "$root" "$id" "$sha" "$hash"
}

write_manifest_fallback() {
  root="$1"; id="$2"; sha="$3"; hash="$4"
  cat >"$root/tasks/$id/evidence.json" <<EOF
{
  "task": "$id",
  "bundle_hash": "$hash",
  "integrated_sha": "$sha",
  "result_class": "DONE",
  "commands": [
    {"cmd": ["sh", "tasks/$id/verify.sh", "host"], "exit": 0}
  ]
}
EOF
}

# prepare_involved_repo <root>
# Creates the fixture's involved repository with the same integration target
# used by jackin and termrock during the run.
prepare_involved_repo() {
  root="$1"
  side="$root.involved"
  if [ ! -d "$side" ]; then
    origin="$root.involved.origins/jackin-project/jackin.git"
    mkdir -p "$(dirname "$origin")"
    git init -q --bare "$origin"
    mkdir -p "$side"
    git init -q "$side"
    git -C "$side" symbolic-ref HEAD refs/heads/feat/managed-execution
    git -C "$side" config user.email fixture@example.invalid
    git -C "$side" config user.name Fixture
    printf 'involved repository\n' >"$side/README.md"
    git -C "$side" add -A
    git -C "$side" commit -q -m "involved: integration target"
    git -C "$side" remote add origin "$origin"
    git -C "$side" push -q -u origin feat/managed-execution
    git -C "$side" fetch -q origin
  fi
}

# make_involved <root> <id> [evidence-sha] [claimed-sha]
# Turns a done fixture task into one that touches an involved repository
# (D-112): its `repos` name another repository, a side clone holds the
# integrated commit, `verify.out` carries the ecosystem `commit:` line and a
# separate `integrated_sha:` line, and `evidence.json` records <evidence-sha>.
# Both SHAs default to the exact integration-target head.
make_involved() {
  root="$1"; id="$2"

  prepare_involved_repo "$root"
  side="$root.involved"
  isha="$(git -C "$side" rev-parse refs/remotes/origin/feat/managed-execution)"
  esha="${3:-$isha}"
  csha="${4:-$isha}"

  printf 'id = "%s"\nlane = "L1"\npath = "container"\nrepos = ["jackin", "host"]\n' \
      "$id" >"$root/tasks/$id/task.toml"
  printf '%s\n' "$side" >"$root/tasks/$id/checkout.txt"
  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: $id touches an involved repository"
  sha="$(git -C "$root" rev-parse HEAD)"
  hash="$( cd "$root" && python3 tools/bundle.py hash "$id" | awk '{print $NF}' )"

  cat >"$root/tasks/$id/verify.out" <<EOF2
task: $id
side: host
commit: $sha
integrated_sha: $csha
bundle_hash: $hash
status: DONE
EOF2
  ( cd "$root" && python3 tools/evidence_manifest.py run --task "$id" \
      --dir "tasks/$id" --bundle-hash "$hash" --integrated-sha "$esha" \
      --repository jackin-project/jackin feat/managed-execution "$esha" "$side" \
      --result-class DONE -- sh -c 'echo fixture' >/dev/null 2>&1 ) || \
  write_manifest_fallback "$root" "$id" "$esha" "$hash"

  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: $id involved evidence"
  git -C "$root" push -q origin main
  git -C "$root" fetch -q origin
}

# make_historical_involved <root> <id>
# Records the exact integration head at task transition time, then advances
# that target. Final verification must retain the historical evidence because
# its SHA is still an ancestor of the later pushed head.
make_historical_involved() {
  root="$1"; id="$2"
  make_involved "$root" "$id"
  side="$root.involved"
  git -C "$side" checkout -q feat/managed-execution
  printf 'later integrated task\n' >"$side/later.txt"
  git -C "$side" add later.txt
  git -C "$side" commit -q -m "involved: later integration"
  git -C "$side" push -q origin feat/managed-execution
  git -C "$side" fetch -q origin
}

# make_divergent_involved <root> <id>
# Claims a commit that exists in the involved repository but is not the head
# of its integration target. An object-existence-only oracle accepts it.
make_divergent_involved() {
  root="$1"; id="$2"
  prepare_involved_repo "$root"
  side="$root.involved"
  target="$(git -C "$side" rev-parse refs/remotes/origin/feat/managed-execution)"
  git -C "$side" checkout -q --detach "$target"
  printf 'divergent commit\n' >"$side/divergent.txt"
  git -C "$side" add divergent.txt
  git -C "$side" commit -q -m "involved: divergent existing commit"
  divergent="$(git -C "$side" rev-parse HEAD)"
  git -C "$side" checkout -q feat/managed-execution
  make_involved "$root" "$id" "$divergent" "$divergent"
}

# make_service_labels <root> <id>
# Service labels are external systems, not involved Git repositories. Their
# evidence remains bound to the ecosystem commit and needs no integrated line.
make_service_labels() {
  root="$1"; id="$2"
  printf 'id = "%s"\nlane = "L1"\npath = "host"\nrepos = ["host", "Linear", "GitHub", "1Password"]\n' \
      "$id" >"$root/tasks/$id/task.toml"
  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: $id uses external services"
  sha="$(git -C "$root" rev-parse HEAD)"
  write_evidence "$root" "$id" "$sha"
  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: $id service evidence"
  git -C "$root" push -q origin main
  git -C "$root" fetch -q origin
}

# make_multi_involved <root> <id> [diverge-second]
# M10-06-shaped proof: two independently integrated repositories. With the
# optional flag, the second record names an existing divergent commit.
make_multi_involved() {
  root="$1"; id="$2"; diverge_second="${3:-0}"

  jackin_side="$root.involved.jackin"
  termrock_side="$root.involved.termrock"
  for identity in \
      "$jackin_side:jackin-project/jackin" \
      "$termrock_side:tailrocks/termrock"; do
    side=${identity%%:*}
    repo=${identity#*:}
    origin="$root.involved.origins/$repo.git"
    mkdir -p "$(dirname "$origin")"
    git init -q --bare "$origin"
    mkdir -p "$side"
    git init -q "$side"
    git -C "$side" symbolic-ref HEAD refs/heads/feat/managed-execution
    git -C "$side" config user.email fixture@example.invalid
    git -C "$side" config user.name Fixture
    printf 'integration target\n' >"$side/README.md"
    git -C "$side" add -A
    git -C "$side" commit -q -m "involved: integration target"
    git -C "$side" remote add origin "$origin"
    git -C "$side" push -q -u origin feat/managed-execution
    git -C "$side" fetch -q origin
  done
  jackin_sha="$(git -C "$jackin_side" rev-parse refs/remotes/origin/feat/managed-execution)"
  termrock_sha="$(git -C "$termrock_side" rev-parse refs/remotes/origin/feat/managed-execution)"
  termrock_claim="$termrock_sha"
  if [ "$diverge_second" -eq 1 ]; then
    git -C "$termrock_side" checkout -q --detach "$termrock_sha"
    printf 'divergent commit\n' >"$termrock_side/divergent.txt"
    git -C "$termrock_side" add divergent.txt
    git -C "$termrock_side" commit -q -m "involved: divergent existing commit"
    termrock_claim="$(git -C "$termrock_side" rev-parse HEAD)"
    git -C "$termrock_side" checkout -q feat/managed-execution
  fi

  printf 'id = "%s"\nlane = "L1"\npath = "container"\nrepos = ["jackin", "termrock"]\n' \
      "$id" >"$root/tasks/$id/task.toml"
  printf '%s\n' "$jackin_side" >"$root/tasks/$id/checkout.txt"
  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: $id touches two involved repositories"
  sha="$(git -C "$root" rev-parse HEAD)"
  hash="$( cd "$root" && python3 tools/bundle.py hash "$id" | awk '{print $NF}' )"

  cat >"$root/tasks/$id/verify.out" <<EOF2
task: $id
side: host
commit: $sha
integrated_sha: $jackin_sha
bundle_hash: $hash
status: DONE
EOF2
  ( cd "$root" && python3 tools/evidence_manifest.py run --task "$id" \
      --dir "tasks/$id" --bundle-hash "$hash" --integrated-sha "$jackin_sha" \
      --repository jackin-project/jackin feat/managed-execution "$jackin_sha" "$jackin_side" \
      --repository tailrocks/termrock feat/managed-execution "$termrock_claim" "$termrock_side" \
      --result-class DONE -- sh -c 'echo fixture' >/dev/null 2>&1 )

  git -C "$root" add -A
  git -C "$root" commit -q -m "fixture: $id multi-repository evidence"
  git -C "$root" push -q origin main
  git -C "$root" fetch -q origin
}
