#!/bin/bash

sudo apt remove -fy "epiphany*"

rm -r $HOME/.local/share/epiphany
rm -r $HOME/.config/epiphany
