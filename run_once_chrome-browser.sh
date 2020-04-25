#!/bin/sh

cd /tmp

wget https://dl.google.com/linux/direct/google-chrome-beta_current_amd64.deb

sudo dpkg -i google-chrome-beta_current_amd64.deb
sudo apt install -f
