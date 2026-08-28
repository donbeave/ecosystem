#!/bin/sh
# services: Linear, GitHub and 1Password labels do not turn a host task into
# an involved Git-repository task -> status: DONE
set -eu
. "$(dirname "$0")/../common.sh"
root="$1"
build_base "$root"
make_service_labels "$root" M1-03
