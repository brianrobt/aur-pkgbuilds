FROM brianrobt/archlinux-aur-dev:latest

RUN sudo pacman -Syu --noconfirm

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD *.diff *.patch ./

# Install build dependencies
RUN yay -S --noconfirm \
  glibc \
  libx11 \
  libxaw \
  libxt

# Build the package
# RUN makepkg -sif --noconfirm
# RUN makepkg --printsrcinfo > .SRCINFO
