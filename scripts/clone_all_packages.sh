#!/bin/bash

# Script to clone all AUR packages listed in repo_urls.txt
# Usage: ./clone_all_packages.sh [CLEAN=true|false]

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URLS_FILE="$SCRIPT_DIR/repo_urls.txt"
MAKEFILE_DIR="$(dirname "$SCRIPT_DIR")"

# Check if repo_urls.txt exists
if [ ! -f "$REPO_URLS_FILE" ]; then
    echo "Error: $REPO_URLS_FILE not found!"
    exit 1
fi

# Check if Makefile exists
if [ ! -f "$MAKEFILE_DIR/Makefile" ]; then
    echo "Error: Makefile not found in $MAKEFILE_DIR!"
    exit 1
fi

# Parse CLEAN parameter
CLEAN="${1:-false}"
if [ "$CLEAN" != "true" ] && [ "$CLEAN" != "false" ]; then
    echo "Error: CLEAN parameter must be 'true' or 'false'"
    echo "Usage: $0 [CLEAN=true|false]"
    echo "Default: CLEAN=false"
    exit 1
fi

echo "Starting to clone all AUR packages..."
echo "CLEAN mode: $CLEAN"
echo "Working directory: $MAKEFILE_DIR"
echo "----------------------------------------"

# Change to the directory containing the Makefile
cd "$MAKEFILE_DIR"

# Counter for tracking progress
TOTAL_PACKAGES=0
SUCCESSFUL_CLONES=0
FAILED_CLONES=0

# Read each line from repo_urls.txt and extract package names
while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Extract package name (everything before the colon)
    PKG_NAME=$(echo "$line" | sed 's/^[0-9]*\. //' | cut -d':' -f1 | xargs)

    if [ -n "$PKG_NAME" ]; then
        TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
        echo "[$TOTAL_PACKAGES] Cloning $PKG_NAME..."

        # Run the make clone command
        if make clone PKG="$PKG_NAME" CLEAN="$CLEAN"; then
            echo "✓ Successfully cloned $PKG_NAME"
            SUCCESSFUL_CLONES=$((SUCCESSFUL_CLONES + 1))
        else
            echo "✗ Failed to clone $PKG_NAME"
            FAILED_CLONES=$((FAILED_CLONES + 1))
        fi

        echo "----------------------------------------"
    fi
done < "$REPO_URLS_FILE"

# Summary
echo "Cloning complete!"
echo "Total packages processed: $TOTAL_PACKAGES"
echo "Successful clones: $SUCCESSFUL_CLONES"
echo "Failed clones: $FAILED_CLONES"

if [ $FAILED_CLONES -gt 0 ]; then
    echo "Some packages failed to clone. Check the output above for details."
    exit 1
else
    echo "All packages cloned successfully!"
    exit 0
fi