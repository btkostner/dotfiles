#!/bin/sh

cd /tmp

wget https://dl.google.com/linux/direct/google-chrome-beta_current_amd64.deb -O chrome.deb

sudo dpkg -i chrome.deb
sudo apt install -fy
