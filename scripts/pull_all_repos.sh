#!/bin/bash

# Script to pull latest Git changes from master branch for each subfolder
# Author: Generated script for AUR package builds

set -e  # Exit on any error

BASE_DIR="/Users/brian/workspace/personal/aur-pkgbuilds"
LOG_FILE="$BASE_DIR/pull_log.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Starting pull operation for all repositories..." | tee "$LOG_FILE"
echo "$(date)" | tee -a "$LOG_FILE"
echo "===========================================" | tee -a "$LOG_FILE"

# Counter for statistics
total_repos=0
successful_pulls=0
failed_pulls=0

# Find all directories with .git folders (excluding the main repo)
for repo_dir in $(find "$BASE_DIR" -name ".git" -type d | grep -v "^$BASE_DIR/.git$" | sed 's|/.git$||'); do
    repo_name=$(basename "$repo_dir")
    total_repos=$((total_repos + 1))
    
    echo -e "\n${YELLOW}Processing: $repo_name${NC}" | tee -a "$LOG_FILE"
    echo "Directory: $repo_dir" | tee -a "$LOG_FILE"
    
    cd "$repo_dir"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not a git repository${NC}" | tee -a "$LOG_FILE"
        failed_pulls=$((failed_pulls + 1))
        continue
    fi
    
    # Get current branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "HEAD")
    echo "Current branch: $current_branch" | tee -a "$LOG_FILE"
    
    # Check if master branch exists
    if git show-ref --verify --quiet refs/heads/master; then
        target_branch="master"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        target_branch="master"
    elif git show-ref --verify --quiet refs/heads/main; then
        target_branch="main"
    elif git show-ref --verify --quiet refs/remotes/origin/main; then
        target_branch="main"
    else
        echo -e "${YELLOW}Warning: No master or main branch found, using current branch${NC}" | tee -a "$LOG_FILE"
        target_branch="$current_branch"
    fi
    
    # Fetch latest changes
    echo "Fetching latest changes..." | tee -a "$LOG_FILE"
    if git fetch origin 2>&1 | tee -a "$LOG_FILE"; then
        # Switch to target branch if not already on it
        if [ "$current_branch" != "$target_branch" ]; then
            echo "Switching to $target_branch branch..." | tee -a "$LOG_FILE"
            if ! git checkout "$target_branch" 2>&1 | tee -a "$LOG_FILE"; then
                echo -e "${RED}Failed to switch to $target_branch branch${NC}" | tee -a "$LOG_FILE"
                failed_pulls=$((failed_pulls + 1))
                continue
            fi
        fi
        
        # Pull latest changes
        echo "Pulling latest changes from origin/$target_branch..." | tee -a "$LOG_FILE"
        if git pull origin "$target_branch" 2>&1 | tee -a "$LOG_FILE"; then
            echo -e "${GREEN}✓ Successfully updated $repo_name${NC}" | tee -a "$LOG_FILE"
            successful_pulls=$((successful_pulls + 1))
        else
            echo -e "${RED}✗ Failed to pull changes for $repo_name${NC}" | tee -a "$LOG_FILE"
            failed_pulls=$((failed_pulls + 1))
        fi
    else
        echo -e "${RED}✗ Failed to fetch changes for $repo_name${NC}" | tee -a "$LOG_FILE"
        failed_pulls=$((failed_pulls + 1))
    fi
done

# Summary
echo -e "\n===========================================" | tee -a "$LOG_FILE"
echo "Pull operation completed!" | tee -a "$LOG_FILE"
echo "Total repositories: $total_repos" | tee -a "$LOG_FILE"
echo -e "${GREEN}Successful pulls: $successful_pulls${NC}" | tee -a "$LOG_FILE"
echo -e "${RED}Failed pulls: $failed_pulls${NC}" | tee -a "$LOG_FILE"
echo "$(date)" | tee -a "$LOG_FILE"

# Return to base directory
cd "$BASE_DIR"

exit 0