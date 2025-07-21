#!/bin/bash

# Script to update all Dockerfiles to use public archlinux:latest base image

# Find all Dockerfiles that use the custom base image
DOCKERFILES=$(find . -name "Dockerfile" -exec grep -l "brianrobt/archlinux-aur-dev" {} \;)

for dockerfile in $DOCKERFILES; do
    echo "Updating $dockerfile..."

    # Create a temporary file
    temp_file=$(mktemp)

    # Replace the FROM line and add the necessary setup
    sed '1s|FROM brianrobt/archlinux-aur-dev:latest|FROM archlinux:latest|' "$dockerfile" > "$temp_file"

    # Insert the setup commands after the FROM line
    awk '
    NR == 1 {
        print $0
        print ""
        print "# Install base development tools and AUR helper"
        print "RUN pacman -Syu --noconfirm && \\"
        print "    pacman -S --noconfirm \\"
        print "    base-devel \\"
        print "    git \\"
        print "    sudo \\"
        print "    yay"
        print ""
        print "# Create builder user (similar to AUR build environment)"
        print "RUN useradd -m -s /bin/bash builder && \\"
        print "    echo \"builder ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers"
        print ""
        print "# Switch to builder user"
        print "USER builder"
        print "WORKDIR /home/builder"
        print ""
        next
    }
    { print }
    ' "$temp_file" > "$dockerfile"

    # Clean up
    rm "$temp_file"

    echo "Updated $dockerfile"
done

echo "All Dockerfiles updated successfully!"