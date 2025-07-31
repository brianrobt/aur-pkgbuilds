#!/bin/bash

# Function to get the latest GitHub release version
get_latest_github_version() {
    local repo_url="$1"
    # Extract owner/repo from GitHub URL
    local repo_path=$(echo "$repo_url" | sed 's|https://github.com/||' | sed 's|/[^/]*$||')
    local repo_name=$(echo "$repo_url" | sed 's|.*/||')
    local full_repo="${repo_path}/${repo_name}"

    # Use GitHub API to get latest release
    local latest_version=$(curl -s "https://api.github.com/repos/${full_repo}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"v*\([^"]*\)".*/\1/')
    echo "$latest_version"
}

# Function to get the latest commit hash from GitHub master/main branch
get_latest_github_commit() {
    local repo_url="$1"
    # Extract owner/repo from GitHub URL
    local repo_path=$(echo "$repo_url" | sed 's|https://github.com/||' | sed 's|/[^/]*$||')
    local repo_name=$(echo "$repo_url" | sed 's|.*/||')
    local full_repo="${repo_path}/${repo_name}"

    # First try master branch
    local latest_commit=$(curl -s "https://api.github.com/repos/${full_repo}/commits/master" | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')
    
    # If master doesn't exist, try main branch
    if [ -z "$latest_commit" ] || [[ "$latest_commit" == *"Not Found"* ]]; then
        latest_commit=$(curl -s "https://api.github.com/repos/${full_repo}/commits/main" | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')
    fi
    
    echo "$latest_commit"
}

# Function to extract current commit hash from git package version
get_current_git_commit() {
    local current_version="$1"
    # Extract commit hash from versions like: r242.1896b28, 1.0.0+r112+g428221ea0, 0.82.0
    if [[ "$current_version" =~ \.([a-f0-9]{7,})$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$current_version" =~ g([a-f0-9]{7,}) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to update PKGBUILD version
update_pkgbuild_version() {
    local pkgbuild_path="$1"
    local new_version="$2"

    # Update pkgver in PKGBUILD
    sed -i.bak "s/^pkgver=.*/pkgver=$new_version/" "$pkgbuild_path"

    # Reset pkgrel to 1
    sed -i.bak "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild_path"

    echo "Updated PKGBUILD: pkgver=$new_version, pkgrel=1"
}

PKGNAME_DIR="$1"

if [ -z "$PKGNAME_DIR" ]; then
    echo "Usage: $0 <package_directory>"
    exit 1
fi

PKGNAME=$(grep "^pkgname=" "$PKGNAME_DIR/PKGBUILD" | sed 's/pkgname=//' | tr -d '"' | tr -d "'")
CONTAINER_NAME="${PKGNAME_DIR}-builder"
IMAGE_NAME="${PKGNAME_DIR}-aur"
AUR_URL="ssh://aur@aur.archlinux.org/${PKGNAME}.git"

echo "Git URL: $AUR_URL"

# Clone the AUR repository
if [ ! -d $PKGNAME_DIR-aur ]; then
  git clone $AUR_URL $PKGNAME_DIR-aur
fi

# Checkout the latest version
cd $PKGNAME_DIR-aur
git checkout master
git pull origin master

# Copy local files to the AUR repository
cp -r ../$PKGNAME_DIR/* .

# Check for version updates
echo "Checking for version updates..."

# Extract URL from PKGBUILD
REPO_URL=$(grep "^url=" PKGBUILD | sed 's/url=//' | tr -d '"' | tr -d "'")
CURRENT_VERSION=$(grep "^pkgver=" PKGBUILD | sed 's/pkgver=//' | tr -d '"' | tr -d "'")

if [ -f Dockerfile ]; then
  if [[ "$PKGNAME_DIR" == *"-git" ]]; then
    # Handle git packages - check for latest commits
    echo "Git package detected: $PKGNAME_DIR"
    echo "Current version: $CURRENT_VERSION"
    echo "Fetching latest commit from: $REPO_URL"
    
    LATEST_COMMIT=$(get_latest_github_commit "$REPO_URL")
    CURRENT_COMMIT=$(get_current_git_commit "$CURRENT_VERSION")
    
    if [ -n "$LATEST_COMMIT" ] && [ -n "$CURRENT_COMMIT" ]; then
        # Compare first 7 characters of commit hashes
        LATEST_SHORT=${LATEST_COMMIT:0:7}
        CURRENT_SHORT=${CURRENT_COMMIT:0:7}
        
        if [ "$LATEST_SHORT" != "$CURRENT_SHORT" ]; then
            echo "New commit available: $LATEST_SHORT (current: $CURRENT_SHORT)"
            echo "Rebuilding package with latest commit..."
        else
            echo "Already at latest commit: $CURRENT_SHORT"
        fi
    elif [ -n "$LATEST_COMMIT" ]; then
        echo "Latest commit: ${LATEST_COMMIT:0:7}"
        echo "Rebuilding package..."
    else
        echo "Could not fetch latest commit from GitHub API"
    fi
    
    # Build the package (always rebuild for git packages to get latest version)
    if [ -f Dockerfile ]; then
      docker build -t $IMAGE_NAME .
      docker run -d --name $CONTAINER_NAME $IMAGE_NAME
      # Copy files from the builder's home directory
      docker cp $CONTAINER_NAME:/home/builder/.SRCINFO .
      docker cp $CONTAINER_NAME:/home/builder/PKGBUILD .
      # Clean up
      docker rm $CONTAINER_NAME
    fi
  elif [[ "$REPO_URL" =~ github\.com ]]; then
      echo "Current version: $CURRENT_VERSION"
      echo "Fetching latest version from: $REPO_URL"

      LATEST_VERSION=$(get_latest_github_version "$REPO_URL")

      if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
          echo "New version available: $LATEST_VERSION"
          update_pkgbuild_version "PKGBUILD" "$LATEST_VERSION"

          # Update checksums using updpkgsums in Docker container
          echo "Updating checksums..."
          # Build temporary image for updpkgsums
          docker build -t "${IMAGE_NAME}" .

          if [ $? -eq 0 ]; then
            docker run -d --name $CONTAINER_NAME $IMAGE_NAME
            # Copy files from the builder's home directory
            docker cp $CONTAINER_NAME:/home/builder/.SRCINFO .
            docker cp $CONTAINER_NAME:/home/builder/PKGBUILD .
            # Clean up
            docker rm $CONTAINER_NAME
          else
              echo "Failed to build Docker image for updpkgsums"
              exit 1
          fi
      elif [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
          echo "Already at latest version: $CURRENT_VERSION"
      else
          echo "Could not fetch latest version"
      fi
  else
      echo "Non-GitHub repository, version update not supported: $REPO_URL"
  fi
fi
