FROM brianrobt/archlinux-aur-dev:latest

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
RUN makepkg -si --noconfirm
