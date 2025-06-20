FROM brianrobt/archlinux-aur-dev:latest

RUN sudo pacman -Syu --noconfirm

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD ./

# Install build dependencies
RUN yay -S --noconfirm \
  rust \
  cargo

# Build the package
# RUN makepkg -si