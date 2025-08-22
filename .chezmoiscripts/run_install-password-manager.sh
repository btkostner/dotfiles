#!/bin/sh
# Ran before Chezmoi runs apply to ensure 1Password helpers work.

# exit immediately if op is already in $PATH
type op >/dev/null 2>&1 && exit

case "$(uname -s)" in
Darwin)
    brew install --cask 1password-cli
    ;;
Linux)
    # commands to install op on Linux
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac
