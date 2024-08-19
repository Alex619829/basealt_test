#!/bin/bash
if test -d /usr/local/bin/basealt_script; then
    rm /usr/local/bin/basealt_script
fi

cpan JSON

cp main.pl /usr/local/bin/basealt_script

chmod +x /usr/local/bin/basealt_script

echo "Success: 'basealt_script' installed to your computer"