#!/bin/bash
PKGNAME_DIR="$1"
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

# Copy the PKGBUILD and .SRCINFO files to the AUR repository
cp -r ../$PKGNAME_DIR/* .

# Build the package
if [ -f Dockerfile ]; then
  docker build -t $IMAGE_NAME .

  # Only proceed if the build was successful
  if [ $? -eq 0 ]; then
    # Copy files from the builder's home directory
    docker cp $CONTAINER_NAME:/home/builder/.SRCINFO .
    docker cp $CONTAINER_NAME:/home/builder/PKGBUILD .

    # Clean up
    docker rm $CONTAINER_NAME
  else
    echo "Docker build failed for $PKGNAME_DIR"
    exit 1
  fi
fi