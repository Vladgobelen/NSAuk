#!/bin/sh
cd "/home/diver/Games/wc/CircleLHK/Interface/AddOns/NSAuk/"
j=$(date)
git add .
git commit -m "$1 $j"
git push git@github.com:Vladgobelen/NSAuk.git


