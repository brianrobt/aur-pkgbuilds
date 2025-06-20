#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_URLS_FILE="$SCRIPT_DIR/repo_urls.txt"
BUILD_DIR="$REPO_ROOT/build"

cleanup() {
    if [[ -d "$BUILD_DIR" ]]; then
        echo "Build directory exists at: $BUILD_DIR"
        echo "Use 'make clean' to remove it when done"
    fi
}

trap cleanup EXIT

create_build_dir() {
    if [[ -d "$BUILD_DIR" ]]; then
        echo "Removing existing build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi
    mkdir -p "$BUILD_DIR"
    echo "Created build directory: $BUILD_DIR"
}

copy_package_files() {
    local package_name="$1"
    local source_dir="$SCRIPT_DIR/$package_name"
    local dest_dir="$BUILD_DIR/$package_name"
    
    if [[ ! -d "$source_dir" ]]; then
        echo "Warning: Source directory $source_dir does not exist for package $package_name"
        return 1
    fi
    
    mkdir -p "$dest_dir"
    cp -r "$source_dir"/* "$dest_dir/"
    echo "Copied $package_name files to $dest_dir"
}

main() {
    if [[ ! -f "$REPO_URLS_FILE" ]]; then
        echo "Error: repo_urls.txt not found at $REPO_URLS_FILE"
        exit 1
    fi
    
    create_build_dir
    
    echo "Processing packages from $REPO_URLS_FILE..."
    
    while IFS=': ' read -r line_num package_name repo_url; do
        if [[ -n "$package_name" && -n "$repo_url" ]]; then
            echo "Processing package: $package_name"
            if copy_package_files "$package_name"; then
                echo "✓ Successfully prepared $package_name for publishing"
            else
                echo "✗ Failed to prepare $package_name"
            fi
            echo
        fi
    done < <(grep -n '^[0-9]*\. ' "$REPO_URLS_FILE" | sed 's/^\([0-9]*\):\([0-9]*\)\. \([^:]*\): \(.*\)$/\1 \3 \4/')
    
    echo "All packages prepared in build directory: $BUILD_DIR"
    echo "Directory contents:"
    ls -la "$BUILD_DIR"
    
    echo
    echo "To publish changes, you can now:"
    echo "1. Navigate to each package directory in $BUILD_DIR"
    echo "2. Make your changes"
    echo "3. Use 'makepkg --printsrcinfo > .SRCINFO' to update package info"
    echo "4. Commit and push changes to AUR"
    echo
    echo "Build directory is ready at: $BUILD_DIR"
    echo "Use 'make clean' to remove the build directory when done."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi