#!/bin/bash

for dir in */; do
    if [[ "$dir" != ".github/" ]]; then
        echo "Processing $dir"
        cd "$dir"
        if git remote | grep -q "^origin$"; then
            git remote remove origin
            echo "Removed origin remote from $dir"
        elif git remote | grep -q "^aur$"; then
            git remote remove aur
            echo "Removed aur remote from $dir"
        else
            echo "No origin remote found in $dir"
        fi
        rm -rf .git
        cd ..
    fi
done