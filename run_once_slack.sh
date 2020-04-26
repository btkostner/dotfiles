#!/bin/sh

cd /tmp

wget https://downloads.slack-edge.com/linux_releases/slack-desktop-4.4.2-amd64.deb -O slack.deb

sudo dpkg -i slack.deb
sudo apt install -fy
