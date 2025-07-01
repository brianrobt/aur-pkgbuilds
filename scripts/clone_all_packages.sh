#!/bin/bash

# clone_all_packages.sh - Update all submodules and copy files for all packages
# Usage: ./scripts/clone_all_packages.sh [clean]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

CLEAN="${1:-false}"

print_status "Updating all AUR submodules and copying files..."

# Read package names from repo_urls.txt
while IFS=':' read -r pkg_name url; do
    # Skip empty lines and comments
    [[ -z "$pkg_name" || "$pkg_name" =~ ^[[:space:]]*# ]] && continue

    # Trim whitespace
    pkg_name=$(echo "$pkg_name" | xargs)

    print_status "Processing package: $pkg_name"

    # Call the individual clone script for each package
    if [ "$CLEAN" = "true" ]; then
        ./scripts/clone.sh "$pkg_name" clean
    else
        ./scripts/clone.sh "$pkg_name"
    fi

    echo ""  # Add blank line between packages

done < "scripts/repo_urls.txt"

print_status "All packages processed successfully!"