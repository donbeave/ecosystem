#!/bin/sh
# Adversarial evidence acceptance tests. Every mutation is committed and
# pushed so only the evidence defect can make the root oracle reject it.
set -u

REPO=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
. "$REPO/tests/fixtures/common.sh"
fixture_repo_root() { printf '%s\n' "$REPO"; }

WORK=$(mktemp -d) || exit 2
trap 'rm -rf "$WORK"' EXIT INT TERM
failures=0

mutate_manifest() {
	root=$1
	case_name=$2
	manifest="$root/tasks/M1-03/evidence.json"
	if [ "$case_name" = outside-task-path ]; then
		mv "$manifest" "$root/tasks/foreign-evidence.json"
		ln -s ../foreign-evidence.json "$manifest"
		return
	fi
	python3 - "$manifest" "$case_name" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
case = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))
command = data["commands"][0]
if case == "wrong-task":
    data["task"] = "M9-99"
elif case == "wrong-bundle":
    data["bundle_hash"] = "0" * 64
elif case == "wrong-integrated-sha":
    data["integrated_sha"] = "0" * 40
elif case == "failed-command":
    command["exit_code"] = 1
elif case == "invalid-timestamp":
    command["started"] = "not-a-utc-timestamp"
elif case == "reversed-timestamps":
    command["started"] = "2026-08-28T00:00:01Z"
    command["finished"] = "2026-08-28T00:00:00Z"
elif case == "failed-result":
    data["result_class"] = "FAILED SYSTEM"
elif case == "unknown-schema-field":
    data["agent_asserted_pass"] = True
else:
    raise SystemExit("unknown case: " + case)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
}

for case_name in \
	wrong-task wrong-bundle wrong-integrated-sha failed-command \
	invalid-timestamp reversed-timestamps failed-result \
	outside-task-path unknown-schema-field
do
	root="$WORK/$case_name"
	build_base "$root" || exit 2
	mutate_manifest "$root" "$case_name"
	git -C "$root" add -A
	git -C "$root" commit -q -m "fixture: $case_name evidence"
	git -C "$root" push -q origin main
	git -C "$root" fetch -q origin
	sh "$REPO/verify.sh" --root "$root" --expect 3 >"$WORK/$case_name.out" 2>&1
	got=$(tail -n 1 "$WORK/$case_name.out")
	if [ "$got" = "status: FAILED SYSTEM" ]; then
		printf '%s\n' "$case_name: ok"
	else
		printf '%s\n' "$case_name: accepted ($got)"
		failures=$((failures + 1))
	fi
done

if [ "$failures" -eq 0 ]; then
	printf '%s\n' 'status: DONE'
	exit 0
fi
printf '%s\n' "$failures evidence forgery case(s) accepted"
printf '%s\n' 'status: FAILED SYSTEM'
exit 1
