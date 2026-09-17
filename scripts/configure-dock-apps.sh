#!/usr/bin/env sh

set -eu

[ "$(uname -s)" = Darwin ] || exit 0

dockutil --remove all --no-restart

for app in \
  "/Applications/Google Chrome.app" \
  "/Applications/Slack.app" \
  "/System/Applications/Mail.app" \
  "/System/Applications/Calendar.app" \
  "/System/Applications/Reminders.app" \
  "/System/Applications/Music.app" \
  "/System/Applications/Notes.app" \
  "/Applications/Notion.app" \
  "/Applications/Linear.app" \
  "/Applications/Paseo.app" \
  "/Applications/Zed.app" \
  "/Applications/Ghostty.app" \
  "/System/Applications/System Settings.app"
do
  [ -d "$app" ] && dockutil --add "$app" --no-restart
done
