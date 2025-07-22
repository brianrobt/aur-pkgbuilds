# Specify target platform architecture
# Use linux/amd64 for x86_64 systems, linux/arm64 for ARM64 systems
# Uncomment the appropriate line for your target architecture:
# FROM --platform=linux/amd64 brianrobt/archlinux-aur-dev:latest
FROM --platform=linux/arm64 brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD refresh-gpg-keys.sh ./

# Refresh GPG keys as workaround to corrupted GPG key error for installing nodejs dependency, simdjson,
# and update the system
USER root
RUN chmod +x refresh-gpg-keys.sh
RUN ./refresh-gpg-keys.sh
RUN pacman -Syu --noconfirm

# Install build dependencies
USER builder
RUN yay -S --noconfirm \
    nodejs \
    npm

# Build and install the package
RUN makepkg -sif --noconfirm
