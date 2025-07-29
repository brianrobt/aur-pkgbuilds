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
  if [[ "$REPO_URL" =~ github\.com ]]; then
      echo "Current version: $CURRENT_VERSION"
      echo "Fetching latest version from: $REPO_URL"

      LATEST_VERSION=$(get_latest_github_version "$REPO_URL")

      if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
          echo "New version available: $LATEST_VERSION"
          update_pkgbuild_version "PKGBUILD" "$LATEST_VERSION"

          # Update checksums using updpkgsums in Docker container
          echo "Updating checksums..."
          # Build temporary image for updpkgsums
          docker build -t "${IMAGE_NAME}-updpkgsums" .

          if [ $? -eq 0 ]; then
              # Run updpkgsums in container
              docker run --rm -v "$(pwd):/build" "${IMAGE_NAME}-updpkgsums" sh -c "cd /build && updpkgsums && makepkg --printsrcinfo > .SRCINFO"

              # Clean up temp image
              docker rmi "${IMAGE_NAME}-updpkgsums" >/dev/null 2>&1

              echo "Version updated to $LATEST_VERSION and checksums updated"
          else
              echo "Failed to build Docker image for updpkgsums"
              exit 1
          fi
      elif [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
          echo "Already at latest version: $CURRENT_VERSION"
      else
          echo "Could not fetch latest version"
      fi
  elif [[ $(echo $PKGNAME_DIR | rev | cut -d- -f2 | rev) == "git" ]]; then
    # Build the package
    if [ -f Dockerfile ]; then
      docker build -t $IMAGE_NAME .
      docker run -d --name $CONTAINER_NAME $IMAGE_NAME
      # Copy files from the builder's home directory
      docker cp $CONTAINER_NAME:/home/builder/.SRCINFO .
      docker cp $CONTAINER_NAME:/home/builder/PKGBUILD .
      # Clean up
      docker rm $CONTAINER_NAME
    fi
  else
      echo "Non-GitHub repository, version update not supported: $REPO_URL"
  fi
fi
