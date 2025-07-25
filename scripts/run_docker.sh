#!/bin/bash
PKGNAME_DIR="$1"
PKGNAME=$(grep "^pkgname=" "$PKGNAME_DIR/PKGBUILD" | sed 's/pkgname=//' | tr -d '"' | tr -d "'")
CONTAINER_NAME="${PKGNAME_DIR}-builder"
IMAGE_NAME="${PKGNAME_DIR}-aur"
AUR_URL="ssh://aur@aur.archlinux.org/${PKGNAME}.git"

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

  # Start container with specific name
  docker run -d --name $CONTAINER_NAME $IMAGE_NAME

  # Copy files from the builder's home directory
  docker cp $CONTAINER_NAME:/home/builder/.SRCINFO .
  docker cp $CONTAINER_NAME:/home/builder/PKGBUILD .

  # Clean up
  docker rm $CONTAINER_NAME
fi