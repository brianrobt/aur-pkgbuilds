#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS] <package_directory>"
    echo ""
    echo "Options:"
    echo "  --user <name>     Set Git user.name"
    echo "  --email <email>   Set Git user.email"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --user 'Thompson, Brian' --email 'brianrobt@pm.me' my-package"
}

# Parse command line arguments
GIT_USER_ARG=""
GIT_EMAIL_ARG=""
PKGNAME_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            GIT_USER_ARG="$2"
            shift 2
            ;;
        --email)
            GIT_EMAIL_ARG="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$PKGNAME_DIR" ]; then
                PKGNAME_DIR="$1"
            else
                echo "Multiple package directories specified. Only one allowed."
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

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

# Function to compare version numbers
compare_versions() {
    local version1="$1"
    local version2="$2"

    # Use sort -V for version comparison (natural sort)
    if [ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -1)" = "$version1" ] && [ "$version1" != "$version2" ]; then
        echo "older"
    elif [ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -1)" = "$version2" ] && [ "$version1" != "$version2" ]; then
        echo "newer"
    else
        echo "equal"
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

# Validate required arguments
if [ -z "$PKGNAME_DIR" ]; then
    echo "Error: Package directory is required"
    show_usage
    exit 1
fi

# Configure Git user and email if provided
if [ -n "$GIT_USER_ARG" ]; then
    echo "Setting Git user.name to: $GIT_USER_ARG"
    git config --global user.name "$GIT_USER_ARG"
fi

if [ -n "$GIT_EMAIL_ARG" ]; then
    echo "Setting Git user.email to: $GIT_EMAIL_ARG"
    git config --global user.email "$GIT_EMAIL_ARG"
fi

# Check if we have proper git authentication for the aur-pkgbuilds repository
echo "Checking git authentication for aur-pkgbuilds repository..."
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Warning: GITHUB_TOKEN not set. Push to aur-pkgbuilds may fail."
    echo "To fix this, set the GITHUB_TOKEN environment variable with a personal access token."
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

# Check Git user permissions
cd $PKGNAME_DIR-aur
echo "Checking Git user permissions..."

# Get current Git user and email
GIT_USER=$(git config user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config user.email 2>/dev/null || echo "")

if [ -z "$GIT_USER" ] || [ -z "$GIT_EMAIL" ]; then
    echo "Warning: Git user.name or user.email not configured"
    echo "Current Git user.name: $GIT_USER"
    echo "Current Git user.email: $GIT_EMAIL"
    echo "Please configure Git user credentials before proceeding"
    exit 1
fi

echo "Git user configured: $GIT_USER <$GIT_EMAIL>"

# Test write access by attempting to fetch and check if we can push
echo "Testing write access to AUR repository..."
if git ls-remote --exit-code origin >/dev/null 2>&1; then
    echo "✓ Repository access confirmed"

    # Check if we have write access by testing push capability
    # This is a conservative check - we'll know for sure when we actually try to push
    echo "Note: Write access will be verified when attempting to push changes"
else
    echo "✗ Cannot access repository. Check SSH key configuration and AUR access permissions"
    exit 1
fi

# Checkout the latest version
git checkout master
git pull origin master

# Compare local and AUR versions before copying
echo "Comparing local and AUR versions..."
LOCAL_VERSION=$(grep "^pkgver=" ../$PKGNAME_DIR/PKGBUILD | sed 's/pkgver=//' | tr -d '"' | tr -d "'")
AUR_VERSION=$(grep "^pkgver=" PKGBUILD | sed 's/pkgver=//' | tr -d '"' | tr -d "'")

echo "Local version: $LOCAL_VERSION"
echo "AUR version: $AUR_VERSION"

VERSION_COMPARISON=$(compare_versions "$LOCAL_VERSION" "$AUR_VERSION")

if [ "$VERSION_COMPARISON" = "newer" ]; then
    echo "Local version is newer than AUR version. Copying files..."
    cp -r ../$PKGNAME_DIR/* .
elif [ "$VERSION_COMPARISON" = "equal" ]; then
    echo "Local and AUR versions are equal. Skipping file copy."
else
    echo "Local version is older than AUR version. Syncing local directory with AUR repository..."

    # Copy AUR repository contents to local directory
    cp -r ./* ../$PKGNAME_DIR/

    # Change to the aur-pkgbuilds repository root
    cd ..

    git config user.name "$GIT_USER"
    git config user.email "$GIT_EMAIL"

    # Add and commit the changes to aur-pkgbuilds repository
    echo "Committing updated files to aur-pkgbuilds repository..."
    git add $PKGNAME_DIR/
    git commit -m "build($PKGNAME): sync with AUR repository (version $AUR_VERSION)"

    # Push changes to aur-pkgbuilds repository
    echo "Pushing changes to aur-pkgbuilds repository..."

    # Configure git to use token-based authentication if GITHUB_TOKEN is available
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Using GitHub token for authentication..."
        git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/brianrobt/aur-pkgbuilds.git"
    fi

    if ! git push origin master; then
        echo "ERROR: Failed to push changes to aur-pkgbuilds repository"
        echo "Please check your Git credentials and repository permissions"
        echo "You may need to set the GITHUB_TOKEN environment variable"
        exit 1
    fi

    echo "Successfully synced local directory with AUR repository and pushed to aur-pkgbuilds"

    # Change back to AUR repository directory for the rest of the script
    cd $PKGNAME_DIR-aur
fi

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
