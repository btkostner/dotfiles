#!/bin/sh
set -eu

if [ "$(uname -s)" != Darwin ]; then
  exit 0
fi

PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

case "${1:-}" in
--migrate-service)
  mkdir -p "$HOME/Library/Logs"
  [ "$(uname -m)" = arm64 ] || exit 0
  # Run before mise loads its agent. Never stop the native agent on reapply.
  if launchctl print "gui/$(id -u)/sh.brew.socktainer" >/dev/null 2>&1; then
    brew services stop socktainer
    if launchctl print "gui/$(id -u)/sh.brew.socktainer" >/dev/null 2>&1; then
      echo "Homebrew's Socktainer service is still registered; refusing to start a second daemon." >&2
      exit 1
    fi
  fi
  exit 0
  ;;
"")
  [ "$(uname -m)" = arm64 ] || exit 0
  ;;
*)
  echo "Usage: $0 [--migrate-service]" >&2
  exit 1
  ;;
esac

socket=/opt/homebrew/var/run/socktainer/.socktainer/container.sock

# A first boot may need to install Apple's kernel before the socket is ready.
attempt=0
until curl --fail --silent --max-time 1 --unix-socket "$socket" --request-target /_ping localhost >/dev/null; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "Socktainer did not become ready within 300 seconds. Check $HOME/Library/Logs/socktainer.err.log." >&2
    exit 1
  fi
  sleep 5
done
