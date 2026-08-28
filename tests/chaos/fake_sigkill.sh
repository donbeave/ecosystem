#!/bin/sh
# Coordinator variant that is killed outright, standing in for a session whose
# process disappears without any message at all (readiness plan 3.3). The
# recovery rehearsal must observe the exit code and explicitly resume from
# durable state.

set -eu

printf '%s coordinator starting; about to be SIGKILLed\n' \
	"$(date -u +%Y-%m-%dT%H:%M:%SZ)"
kill -9 $$
sleep 60
