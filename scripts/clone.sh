#!/bin/bash

# clone.sh - Update submodule and copy files for a specific package
# Usage: ./scripts/clone.sh <package-name> [clean]

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

# Check if package name is provided
if [ $# -eq 0 ]; then
    print_error "Package name required. Usage: $0 <package-name> [clean]"
    print_error "Example: $0 proton-pass-bin"
    print_error "Optional: add 'clean' as second argument to remove temp directories"
    exit 1
fi

PKG="$1"
CLEAN="${2:-false}"
SUBMODULE_DIR="${PKG}/${PKG}-aur"

print_status "Updating Git submodule for $PKG..."

# Check if submodule directory exists in .gitmodules
if ! grep -q "\[submodule \"$SUBMODULE_DIR\"\]" .gitmodules 2>/dev/null; then
    print_error "Submodule $SUBMODULE_DIR not found in .gitmodules"
    print_error "Make sure the submodule is properly configured"
    exit 1
fi

# Update the specific submodule
git submodule update --init --recursive "$SUBMODULE_DIR"

print_status "Copying files from submodule to package directory..."
# Create package directory if it doesn't exist
mkdir -p "$PKG"

# Copy all files from submodule, excluding .git but including other dotfiles
if [ -d "$SUBMODULE_DIR" ]; then
    cd "$SUBMODULE_DIR"
    # Use rsync to copy files, excluding .git directory but including other dotfiles
    rsync -av --exclude='.git' . "../"
    cd - > /dev/null
    print_status "Files copied successfully from submodule"
else
    print_error "Submodule directory $SUBMODULE_DIR not found"
    print_error "Make sure the submodule is properly configured in .gitmodules"
    exit 1
fi

# Handle cleanup based on CLEAN parameter
if [ "$CLEAN" = "clean" ] || [ "$CLEAN" = "true" ]; then
    print_status "Removing temporary clone directory..."
    rm -rf "$PKG/temp_clone" 2>/dev/null || true
else
    print_status "Keeping temporary clone directory at $PKG/temp_clone (if it exists)"
fi

print_status "Successfully updated $PKG from submodule"