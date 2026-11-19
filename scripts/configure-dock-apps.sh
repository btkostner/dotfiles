#!/usr/bin/env sh

set -eu

[ "$(uname -s)" = Darwin ] || exit 0
command -v dockutil >/dev/null 2>&1 || exit 0

dockutil --remove all --no-restart

for app in \
  "/Applications/Google Chrome.app" \
  "/Applications/Slack.app" \
  "/System/Applications/Mail.app" \
  "/System/Applications/Calendar.app" \
  "/System/Applications/Reminders.app" \
  "/System/Applications/Music.app" \
  "/System/Applications/Notes.app" \
  "/Applications/Zed.app" \
  "/Applications/Rex Beta.app" \
  "/System/Applications/System Settings.app"; do
  [ -d "$app" ] && dockutil --add "$app" --no-restart
done
