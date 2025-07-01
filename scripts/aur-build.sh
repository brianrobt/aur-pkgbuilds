#!/bin/bash

# aur-build.sh - Build and run AUR package in Docker
# Usage: ./scripts/aur-build.sh <package-name>

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
    print_error "Example: $0 proton-pass-bin"
    exit 1
fi

PKG="$1"
SUBMODULE_DIR="${PKG}/${PKG}-aur"

print_status "Step 1: Updating Git submodule for $PKG..."
# Update the specific submodule
git submodule update --init --recursive "$SUBMODULE_DIR"

print_status "Step 2: Copying files from submodule to package directory..."
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

print_status "Step 3: Checking for Dockerfile and building image..."
if [ -f "$PKG/Dockerfile" ]; then
    print_status "Dockerfile found. Building Docker image $PKG-aur..."
    cd "$PKG" && docker build -t "$PKG-aur" .
    print_status "Step 4: Running Docker container..."
    docker run -it "$PKG-aur"
else
    print_warning "No Dockerfile found in $PKG/ directory."
    print_warning "Skipping Docker build and run steps."
    print_warning "You can manually build and run the package if needed."
fi