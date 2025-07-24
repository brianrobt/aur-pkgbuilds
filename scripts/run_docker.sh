#!/bin/bash
PKGNAME="openmohaa"
CONTAINER_NAME="${PKGNAME}-builder"
IMAGE_NAME="${PKGNAME}-aur"

# Start container with specific name
docker run -d --name $CONTAINER_NAME $IMAGE_NAME

# Copy files using the known name
docker cp $CONTAINER_NAME:/workspace/. .

# Clean up
docker rm $CONTAINER_NAME