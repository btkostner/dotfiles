#!/usr/bin/env sh
#
# Adds the third-party apt repositories that [bootstrap.packages] installs
# from, plus starship, which has no apt repository outside Debian 13+.
#
# Run from [bootstrap.hooks.pre-packages], so it lands before mise installs
# anything. Idempotent, and a no-op anywhere that is not Debian-like.

set -eu

[ "$(uname -s)" = "Linux" ] || exit 0

if ! command -v apt-get >/dev/null 2>&1; then
  echo "linux-repos: no apt-get, nothing to do" >&2
  exit 0
fi

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# curl and gnupg are themselves declared in [bootstrap.packages], but that runs
# after this hook and every step below needs them.
if ! command -v curl >/dev/null 2>&1 || ! command -v gpg >/dev/null 2>&1; then
  echo "==> installing curl and gnupg"
  as_root apt-get update -qq
  as_root apt-get install -y --no-install-recommends curl gnupg ca-certificates
fi

KEYRINGS=/etc/apt/keyrings
SOURCES=/etc/apt/sources.list.d
ARCH="$(dpkg --print-architecture)"
added=0

as_root install -d -m 0755 "$KEYRINGS" "$SOURCES"

# add_repo <name> <key url> <keyring path> <sources line>
add_repo() {
  name="$1"
  key_url="$2"
  keyring="$3"
  line="$4"
  list="${SOURCES}/${name}.list"

  if [ -f "$keyring" ] && [ -f "$list" ]; then
    return 0
  fi

  echo "==> adding apt repository: ${name}"
  curl -fsSL "$key_url" | as_root gpg --dearmor --yes --output "$keyring"
  as_root chmod 0644 "$keyring"
  echo "$line" | as_root tee "$list" >/dev/null
  added=1
}

add_repo nushell \
  https://apt.fury.io/nushell/gpg.key \
  "${KEYRINGS}/fury-nushell.gpg" \
  "deb [signed-by=${KEYRINGS}/fury-nushell.gpg] https://apt.fury.io/nushell/ /"

add_repo github-cli \
  https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  "${KEYRINGS}/githubcli-archive-keyring.gpg" \
  "deb [arch=${ARCH} signed-by=${KEYRINGS}/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

add_repo 1password \
  https://downloads.1password.com/linux/keys/1password.asc \
  "${KEYRINGS}/1password-archive-keyring.gpg" \
  "deb [arch=${ARCH} signed-by=${KEYRINGS}/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/${ARCH} stable main"

# 1Password's packages are debsig-signed on top of the repository signature,
# and dpkg rejects them outright without a matching policy.
DEBSIG_ID=AC2D62742012EA22
DEBSIG_POLICY="/etc/debsig/policies/${DEBSIG_ID}/1password.pol"
if [ ! -f "$DEBSIG_POLICY" ]; then
  echo "==> installing 1password debsig policy"
  as_root install -d -m 0755 \
    "/etc/debsig/policies/${DEBSIG_ID}" \
    "/usr/share/debsig/keyrings/${DEBSIG_ID}"
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
    as_root tee "$DEBSIG_POLICY" >/dev/null
  curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
    as_root gpg --dearmor --yes \
      --output "/usr/share/debsig/keyrings/${DEBSIG_ID}/debsig.gpg"
  added=1
fi

if [ "$added" -eq 1 ]; then
  echo "==> apt-get update"
  as_root apt-get update -qq
fi

# starship reached apt in Debian 13; Ubuntu does not carry it at all, so fall
# back to the installer upstream documents. Not a [bootstrap.packages] entry
# because a missing apt package is a hard error there.
if ! command -v starship >/dev/null 2>&1; then
  if apt-cache show starship >/dev/null 2>&1; then
    echo "==> installing starship from apt"
    as_root apt-get install -y starship
  else
    echo "==> installing starship from starship.rs"
    curl -sS https://starship.rs/install.sh | as_root sh -s -- --yes
  fi
fi
