#!/bin/bash

# aur-push.sh - Push AUR package updates to the AUR repository
# Usage: ./scripts/aur-push.sh <package-name>

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
    print_error "Package name required. Usage: $0 <package-name>"
    print_error "Example: $0 openmohaa-git"
    exit 1
fi

PKG="$1"
AUR_CLONE_DIR="${PKG}-aur"

# Check if package directory exists
if [ ! -d "$PKG" ]; then
    print_error "Package directory $PKG not found"
    exit 1
fi

print_status "Step 1: Cloning AUR package $PKG..."
# Remove existing clone directory if it exists
if [ -d "$AUR_CLONE_DIR" ]; then
    print_warning "Removing existing clone directory $AUR_CLONE_DIR"
    rm -rf "$AUR_CLONE_DIR"
fi

# Clone the AUR package
git clone "ssh://aur@aur.archlinux.org/$PKG.git" "$AUR_CLONE_DIR"

print_status "Step 2: Copying files from $PKG to $AUR_CLONE_DIR..."
# Copy all files from package directory to AUR clone, excluding the AUR clone directory itself
rsync -av --exclude="$AUR_CLONE_DIR" --exclude=".git" "$PKG/" "$AUR_CLONE_DIR/"

print_status "Step 3: Generating commit message with oco..."
cd "$AUR_CLONE_DIR"

# Check if oco is available
if ! command -v oco &> /dev/null; then
    print_error "oco command not found. Please install it first:"
    print_error "npm install -g opencommit"
    exit 1
fi

# Add all changes
git add .

# Check if there are any changes to commit
if git diff --cached --quiet; then
    print_warning "No changes to commit"
    cd ..
    rm -rf "$AUR_CLONE_DIR"
    exit 0
fi

# Generate commit message and commit
print_status "Generating commit message..."
oco

print_status "Step 4: Pushing to AUR..."
git push origin master

print_status "Step 5: Cleaning up..."
cd ..
rm -rf "$AUR_CLONE_DIR"

print_status "Successfully pushed $PKG to AUR and cleaned up"