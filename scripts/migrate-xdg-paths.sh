#!/bin/sh
set -eu

move_dir() {
  source_path=$1
  target_path=$2

  if [ -e "$source_path" ]; then
    if [ -e "$target_path" ]; then
      printf '%s\n' "Refusing to replace $target_path with $source_path" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$target_path")"
    mv "$source_path" "$target_path"
  fi
}

move_file() {
  source_path=$1
  target_path=$2

  if [ -f "$source_path" ]; then
    if [ -e "$target_path" ]; then
      printf '%s\n' "Refusing to replace $target_path with $source_path" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$target_path")"
    mv "$source_path" "$target_path"
  fi
}
move_empty_target_dir() {
  source_path=$1
  target_path=$2

  if [ -d "$source_path" ]; then
    if [ -e "$target_path" ]; then
      rmdir "$target_path" 2>/dev/null || {
        printf '%s\n' "Refusing to merge $source_path into non-empty $target_path" >&2
        exit 1
      }
    fi
    mkdir -p "$(dirname "$target_path")"
    mv "$source_path" "$target_path"
  fi
}

move_file "$HOME/.aws/config" "$HOME/.config/aws/config"
move_file "$HOME/.aws/credentials" "$HOME/.config/aws/credentials"
move_dir "$HOME/.docker" "$HOME/.config/docker"
move_dir "$HOME/.cargo" "$HOME/.local/share/cargo"
move_dir "$HOME/.rustup" "$HOME/.local/share/rustup"
move_dir "$HOME/.npm" "$HOME/.cache/npm"
move_file "$HOME/.npmrc" "$HOME/.config/npm/npmrc"
move_dir "$HOME/.claude" "$HOME/.local/share/claude-code"
move_dir "$HOME/.codex" "$HOME/.local/share/codex"
move_dir "$HOME/.hex" "$HOME/.local/share/hex"
move_file "$HOME/.kube/config" "$HOME/.config/kube/config"
move_dir "$HOME/.kube/cache" "$HOME/.cache/kubectl"
move_empty_target_dir "$HOME/go/pkg/mod" "$HOME/.cache/go/mod"
move_dir "$HOME/go" "$HOME/.local/share/go"

mkdir -p \
  "$HOME/.cache/go/mod" \
  "$HOME/.cache/go/build" \
  "$HOME/.cache/npm" \
  "$HOME/.cache/terraform/plugin-cache" \
  "$HOME/.cache/pip" \
  "$HOME/.cache/deno" \
  "$HOME/.cache/bun" \
  "$HOME/.cache/yarn" \
  "$HOME/.cache/python" \
  "$HOME/.cache/uv" \
  "$HOME/.cache/mise" \
  "$HOME/.cache/wrangler" \
  "$HOME/.config/aws" \
  "$HOME/.config/docker" \
  "$HOME/.config/go" \
  "$HOME/.config/npm" \
  "$HOME/.config/kube" \
  "$HOME/.config/terraform" \
  "$HOME/.config/pip" \
  "$HOME/.local/share/cargo" \
  "$HOME/.local/share/rustup" \
  "$HOME/.local/share/npm" \
  "$HOME/.local/share/go" \
  "$HOME/.local/share/uv/tools" \
  "$HOME/.local/share/uv/python" \
  "$HOME/.local/share/claude-code" \
  "$HOME/.local/share/codex" \
  "$HOME/.local/share/hex" \
  "$HOME/.local/state/aws/cli/history" \
  "$HOME/.local/state/node" \
  "$HOME/.local/state/mise"
