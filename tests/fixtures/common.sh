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
SHA-256 of the task's three bundle files, in a fixed order."""
import hashlib
import sys

if len(sys.argv) != 3 or sys.argv[1] != "hash":
    sys.stderr.write("usage: bundle.py hash <task-id>\n")
    raise SystemExit(2)

digest = hashlib.sha256()
for name in ("TASK.md", "task.toml", "verify.sh"):
    with open("tasks/%s/%s" % (sys.argv[2], name), "rb") as handle:
        digest.update(handle.read())
print(digest.hexdigest())
PY
}

write_defects() {
  cat >"$1/PREFLIGHT-DEFECTS.md" <<'MD'
# Preflight defects

| # | Task | Missing item | Proof it is in place | Recorded (UTC) | Resolved (UTC) |
| --- | --- | --- | --- | --- | --- |
MD
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
  # to its fixture status. The projections are rewritten by the store itself.
  ( cd "$root" && python3 tools/roadmap_compile.py --json --expect 3 ROADMAP.md >run/dag.json 2>/dev/null )
  ( cd "$root" && python3 tools/state.py init --dag run/dag.json --run-id fixture >/dev/null )
  for id in M1-01 M1-02; do
    ( cd "$root" && python3 tools/state.py transition "$id" "done" \
        --lane L1 --path host --result "fixture" \
        --evidence "tasks/$id/verify.out" >/dev/null )
  done
  ( cd "$root" && python3 tools/state.py transition M1-03 "$last_status" \
      --lane L1 --path host --result "fixture" \
      --evidence "tasks/M1-03/verify.out" >/dev/null )

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
  hash="$( cd "$root" && python3 tools/bundle.py hash "$id" )"
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
