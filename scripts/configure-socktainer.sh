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

export DOCKER_CONFIG="${DOCKER_CONFIG:-$HOME/.config/docker}"
export DOCKER_HOST=unix:///opt/homebrew/var/run/socktainer/.socktainer/container.sock
# An explicitly selected context would override DOCKER_HOST.
unset DOCKER_CONTEXT

# A first boot may need to install Apple's kernel before the socket is ready.
attempt=0
until docker info >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "Socktainer did not become ready within 300 seconds. Check $HOME/Library/Logs/socktainer.err.log." >&2
    exit 1
  fi
  sleep 5
done

if ! docker network inspect socktainer-build >/dev/null 2>&1; then
  networks=$(docker network ls --format '{{.Name}}')
  if printf '%s\n' "$networks" | grep -Fxq socktainer-build; then
    echo "The existing socktainer-build network could not be inspected." >&2
    exit 1
  fi
  docker network create socktainer-build
fi

if ! builder=$(docker buildx inspect socktainer 2>&1); then
  builders=$(docker buildx ls --format '{{.Builder.Name}}')
  if printf '%s\n' "$builders" | grep -Fxq socktainer; then
    printf 'The existing socktainer builder could not be inspected:\n%s\n' "$builder" >&2
    exit 1
  fi
  docker buildx create --name socktainer --driver docker-container \
    --driver-opt network=socktainer-build --use "$DOCKER_HOST"
  # No --bootstrap: BuildKit starts on the first build, not during machine setup.
  exit 0
fi

# Inspect prints configured options even when the builder is stopped. Require
# one local node on the DNS-safe network; never silently replace user state.
if ! printf '%s\n' "$builder" | awk -v endpoint="$DOCKER_HOST" '
  /^Driver:/ { driver = $2 }
  /^Endpoint:/ { nodes++; if ($2 != endpoint) invalid = 1 }
  /^Driver Options:/ && /(^|[[:space:]])network="socktainer-build"([[:space:]]|$)/ { networks++ }
  /^[[:space:]]*Error:/ { invalid = 1 }
  END { exit !(driver == "docker-container" && nodes == 1 && networks == 1 && !invalid) }
'; then
  printf '%s\n' \
    'The existing socktainer builder does not match the required configuration:' \
    "  driver=docker-container, endpoint=$DOCKER_HOST, network=socktainer-build" \
    'Inspect it with docker buildx inspect socktainer. Remove or rename it explicitly before rerunning bootstrap.' \
    "$builder" >&2
  exit 1
fi
