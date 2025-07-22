# Specify target platform architecture
# Use linux/amd64 for x86_64 systems, linux/arm64 for ARM64 systems
# Uncomment the appropriate line for your target architecture:
# FROM --platform=linux/amd64 brianrobt/archlinux-aur-dev:latest
FROM --platform=linux/arm64 brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD ./

# Update the system
USER root
RUN pacman -Syu --noconfirm

# Clone a copy of the most recent AUR package
RUN eval "$(ssh-agent -s)"
RUN ssh-add ~/.ssh/id_rsa
RUN git clone ssh://aur@aur.archlinux.org/proton-pass-bin.git

# Install build dependencies
USER builder

# Build the package
RUN makepkg -sif --noconfirm
