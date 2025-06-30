#!/bin/bash

# Script to add submodules for all AUR packages
# Based on scripts/repo_urls.txt

# Read the repo_urls.txt file and add submodules
while IFS=':' read -r package_name repo_url; do
    # Skip empty lines
    if [[ -z "$package_name" ]]; then
        continue
    fi

    # Remove leading/trailing whitespace
    package_name=$(echo "$package_name" | xargs)
    repo_url=$(echo "$repo_url" | xargs)

    # Skip htmlhint as it already has a submodule
    if [[ "$package_name" == "htmlhint" ]]; then
        echo "Skipping $package_name (already has submodule)"
        continue
    fi

    # Check if the package directory exists
    if [[ ! -d "$package_name" ]]; then
        echo "Warning: Directory $package_name does not exist, skipping"
        continue
    fi

    # Check if submodule already exists
    submodule_path="$package_name/${package_name}-aur"
    if [[ -d "$submodule_path" ]]; then
        echo "Warning: Submodule directory $submodule_path already exists, skipping"
        continue
    fi

    echo "Adding submodule for $package_name..."
    git submodule add "$repo_url" "$submodule_path"

    if [[ $? -eq 0 ]]; then
        echo "Successfully added submodule for $package_name"
    else
        echo "Failed to add submodule for $package_name"
    fi

done < scripts/repo_urls.txt

echo "Submodule addition complete!"