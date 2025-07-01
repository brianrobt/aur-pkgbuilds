#!/bin/bash

# clean.sh - Clean up temporary files and directories

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_status "Cleaning up temporary files..."
rm -f pull_log.txt

print_status "Removing all *.backup directories..."
find . -maxdepth 1 -type d -name "*.backup" -exec rm -rf {} + 2>/dev/null || true

print_status "Removing all temp_clone directories..."
find . -type d -name "temp_clone" -exec rm -rf {} + 2>/dev/null || true

print_status "Cleanup complete"