#!/bin/sh

if [ ! -d "$HOME/.bin" ] ; then
    mkdir -p "$HOME/.bin"
fi

if [ -d "$HOME/bin" ] ; then
    for x in $HOME/bin/* ; do
        if [ -e "$x" ]; then mv -- "$x" $HOME/.bin/; fi
    done

    rm -r "$HOME/bin"
fi

