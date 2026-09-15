#!/usr/bin/env sh
#
# [bootstrap.user].login_shell takes one absolute path and neither templates
# nor filters by OS, and nushell has no path that is right everywhere:
# Homebrew puts it in /opt/homebrew/bin, apt in /usr/bin. This keeps
# /usr/local/bin/nu pointed at whichever one is real, so the config can name a
# single stable path.
#
# mise appends the shell to /etc/shells itself before running chsh, so that
# part is not handled here.
#
# Run from [bootstrap.hooks.pre-user].

set -eu

STABLE=/usr/local/bin/nu

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

real="$(command -v nu 2>/dev/null || true)"

if [ -z "$real" ]; then
  echo "register-shell: nu is not installed yet, leaving ${STABLE} alone" >&2
  exit 0
fi

# A real binary already sits at the stable path — nothing to point anywhere.
if [ "$real" = "$STABLE" ] && [ ! -L "$STABLE" ]; then
  exit 0
fi

# PATH found our own symlink. Resolve past it so we never link to ourselves.
if [ "$real" = "$STABLE" ]; then
  real="$(readlink "$STABLE")"
fi

if [ -L "$STABLE" ] && [ "$(readlink "$STABLE")" = "$real" ]; then
  exit 0
fi

echo "==> pointing ${STABLE} at ${real}"
as_root install -d -m 0755 "$(dirname "$STABLE")"
as_root ln -sfn "$real" "$STABLE"
