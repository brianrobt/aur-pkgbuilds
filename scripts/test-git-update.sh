#!/bin/bash

# test-git-update.sh - Test script for git package updates
# This script simulates the GitHub Actions workflow locally

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if package name is provided
if [ $# -eq 0 ]; then
    print_error "Package name required. Usage: $0 <package-name>"
    print_error "Example: $0 openmohaa-git"
    print_error "Use 'all' to test all git packages"
    exit 1
fi

PKG="$1"

# Function to test a single package
test_package() {
    local pkg_name="$1"

    print_step "Testing package: $pkg_name"

    if [ ! -d "$pkg_name" ]; then
        print_error "Package directory $pkg_name not found"
        return 1
    fi

    if [ ! -f "$pkg_name/Dockerfile" ]; then
        print_error "No Dockerfile found for $pkg_name"
        return 1
    fi

    print_status "Building Docker image for $pkg_name..."
    cd "$pkg_name"

    # Build the Docker image
    if ! docker build -t "$pkg_name-test" .; then
        print_error "Failed to build Docker image for $pkg_name"
        cd ..
        return 1
    fi

    print_status "Running container to update files..."

    # Run the container
    CONTAINER_ID=$(docker run -d "$pkg_name-test" tail -f /dev/null)

    # Wait for container to be ready
    sleep 3

    # Run makepkg to update version and generate .SRCINFO
    if ! docker exec "$CONTAINER_ID" bash -c "
        cd /home/builder
        makepkg --printsrcinfo > .SRCINFO
        echo 'Updated PKGBUILD and .SRCINFO files'
        ls -la PKGBUILD .SRCINFO
    "; then
        print_error "Failed to update files in container for $pkg_name"
        docker stop "$CONTAINER_ID" 2>/dev/null || true
        docker rm "$CONTAINER_ID" 2>/dev/null || true
        cd ..
        return 1
    fi

    # Create backup of original files
    if [ -f "PKGBUILD" ]; then
        cp PKGBUILD PKGBUILD.backup
    fi
    if [ -f ".SRCINFO" ]; then
        cp .SRCINFO .SRCINFO.backup
    fi

    # Copy updated files from container
    print_status "Copying updated files from container..."
    docker cp "$CONTAINER_ID:/home/builder/PKGBUILD" "./PKGBUILD.new"
    docker cp "$CONTAINER_ID:/home/builder/.SRCINFO" "./.SRCINFO.new"

    # Clean up container
    docker stop "$CONTAINER_ID"
    docker rm "$CONTAINER_ID"

    # Show differences
    print_status "Checking for changes..."
    if [ -f "PKGBUILD" ] && [ -f "PKGBUILD.new" ]; then
        if diff -q PKGBUILD PKGBUILD.new >/dev/null; then
            print_warning "No changes in PKGBUILD for $pkg_name"
        else
            print_status "PKGBUILD changes detected:"
            diff -u PKGBUILD PKGBUILD.new || true
        fi
    fi

    if [ -f ".SRCINFO" ] && [ -f ".SRCINFO.new" ]; then
        if diff -q .SRCINFO .SRCINFO.new >/dev/null; then
            print_warning "No changes in .SRCINFO for $pkg_name"
        else
            print_status ".SRCINFO changes detected:"
            diff -u .SRCINFO .SRCINFO.new || true
        fi
    fi

    # Ask user if they want to apply changes
    echo
    read -p "Apply changes for $pkg_name? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv PKGBUILD.new PKGBUILD
        mv .SRCINFO.new .SRCINFO
        print_status "Changes applied for $pkg_name"
    else
        print_warning "Changes not applied for $pkg_name"
        rm -f PKGBUILD.new .SRCINFO.new
    fi

    # Clean up backup files
    rm -f PKGBUILD.backup .SRCINFO.backup

    cd ..
    print_status "Completed testing $pkg_name"
    echo
}

# Main execution
if [ "$PKG" = "all" ]; then
    print_step "Testing all git packages"

    # Find all git packages
    GIT_PACKAGES=$(find . -maxdepth 1 -type d -name "*-git" -exec basename {} \; | sort)

    if [ -z "$GIT_PACKAGES" ]; then
        print_error "No git packages found"
        exit 1
    fi

    print_status "Found git packages: $GIT_PACKAGES"
    echo

    for pkg in $GIT_PACKAGES; do
        test_package "$pkg"
    done

    print_status "All packages tested"
else
    test_package "$PKG"
fi

print_status "Test completed successfully"