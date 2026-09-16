#!/usr/bin/env sh
#
# Installs omp (oh-my-pi), the coding agent everything here drives AI work
# through, and keeps /usr/local/bin/omp pointed at it.
#
# Not a [bootstrap.packages] entry: omp ships its own installer and updates
# itself with `omp update`, so like mise it stays out of every package manager
# rather than having one hold it back.
#
# The binary lands in ~/.local/bin, which is on PATH and writable, so
# `omp update` can replace it without sudo. The symlink is what everything
# else gets: Zed names one absolute path in its agent_servers entry, and a GUI
# app launched from the Dock has neither ~/.local/bin nor /opt/homebrew/bin on
# its PATH. Same trick, and same reason, as /usr/local/bin/nu.
#
# Run from [bootstrap.hooks.pre-dotfiles], so the binary the Zed settings name
# is already in place the first time they are rendered. Re-running installs
# nothing once it is there.

set -eu

INSTALL_DIR="${PI_INSTALL_DIR:-${HOME}/.local/bin}"
STABLE=/usr/local/bin/omp

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ ! -x "${INSTALL_DIR}/omp" ]; then
  echo "==> installing omp to ${INSTALL_DIR}"
  # --binary rather than the default, which builds from source through bun
  # when bun happens to be on PATH. Nothing here installs bun, the prebuilt
  # release is the same engine, and pinning the mode keeps the binary in one
  # known place instead of wherever bun puts its global bins.
  curl -fsSL https://omp.sh/install |
    PI_INSTALL_DIR="$INSTALL_DIR" sh -s -- --binary
fi

# A real binary already sits at the stable path — nothing to point anywhere.
if [ -e "$STABLE" ] && [ ! -L "$STABLE" ]; then
  exit 0
fi

if [ -L "$STABLE" ] && [ "$(readlink "$STABLE")" = "${INSTALL_DIR}/omp" ]; then
  exit 0
fi

echo "==> pointing ${STABLE} at ${INSTALL_DIR}/omp"
as_root install -d -m 0755 "$(dirname "$STABLE")"
as_root ln -sfn "${INSTALL_DIR}/omp" "$STABLE"
