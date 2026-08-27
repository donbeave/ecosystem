#!/bin/sh
# Coordinator variant that dies the way a rejected stop hook makes a Claude
# Code session die: it writes a StopFailure line and exits non-zero
# (readiness plan 3.3). The supervisor must observe both facts and resume.

set -eu

printf '%s coordinator starting\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'StopFailure: the stop hook refused to let the session end\n'
printf '%s coordinator exiting 1 after StopFailure\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
exit 1
