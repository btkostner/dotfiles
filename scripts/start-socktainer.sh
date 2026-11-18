#!/bin/sh
set -eu

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || exit 0

# Apple Container keeps its backend and kernel under the real user's HOME.
# Start it explicitly: Socktainer's auto-start can lag Container CLI changes.
container system start --enable-kernel-install

# Retain the Homebrew service's socket location without using its LaunchAgent.
runtime_home=/opt/homebrew/var/run/socktainer
mkdir -p "$runtime_home"
export HOME="$runtime_home"
exec socktainer --no-auto-start --dns-upstream auto
