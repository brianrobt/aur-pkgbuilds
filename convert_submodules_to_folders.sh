#!/bin/bash

# Script to convert all Git submodules to regular folders
# This will remove the submodule references and add the files as regular content

set -e

echo "Converting Git submodules to regular folders..."

# List of all submodule directories
submodules=(
    "arduino-avr-core"
    "gnome-shell-extension-panel-osd"
    "kpeople5"
    "micromamba"
    "openmohaa"
    "openmohaa-git"
    "outwiker"
    "proton-pass-bin"
    "python-abydos"
    "python-conda"
    "python-conda-libmamba-solver"
    "python-hunspell"
    "python-jproperties"
    "python-libmamba"
    "python-npyscreen"
    "python-pytest-freezegun"
    "python-typed-ast"
    "rapidyaml"
    "rot8-git"
    "stable-diffusion-cpp-vulkan-git"
)

# Remove each submodule from Git index
for submodule in "${submodules[@]}"; do
    echo "Processing $submodule..."

    # Remove from Git index (but keep the files)
    git rm --cached "$submodule"

    # Remove .git directory from submodule if it exists
    if [ -d "$submodule/.git" ]; then
        echo "  Removing .git directory from $submodule"
        rm -rf "$submodule/.git"
    fi

    # Add all files from the submodule as regular files
    echo "  Adding files from $submodule as regular content"
    git add "$submodule/"
done

echo "All submodules have been converted to regular folders."
echo "You can now commit these changes with: git commit -m 'Convert submodules to regular folders'"