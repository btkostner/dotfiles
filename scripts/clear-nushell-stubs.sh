#!/usr/bin/env sh
#
# Nushell writes stub config.nu and env.nu files the first time it is
# installed — apt's postinst triggers this — and they sit exactly where this
# repo deploys its own, so the dotfiles phase refuses to overwrite them.
#
# Run from [bootstrap.hooks.pre-dotfiles]. The stubs are pure comments with a
# header nushell generates; anything without that header is left alone, so
# this never touches a file we put there.

set -eu

NUSHELL_DIR="${HOME}/.config/nushell"

for name in config.nu env.nu; do
  path="${NUSHELL_DIR}/${name}"

  [ -f "$path" ] || continue
  [ -L "$path" ] && continue

  if head -n 8 "$path" | grep -q '^# Installed by:'; then
    echo "==> removing nushell's stock ${name}"
    rm -f "$path"
  fi
done
