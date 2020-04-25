#!/bin/sh

cd /tmp

wget https://atom.io/download/deb -O atom.deb

sudo dpkg -i atom.deb
sudo apt install -fy

apm install package-sync
