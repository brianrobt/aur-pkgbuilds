FROM brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD ./

USER root
RUN pacman -Syu --noconfirm

# Install build dependencies
USER builder
RUN yay -S --noconfirm \
    cmake \
    ninja \
    openal \
    sdl2 \
    openjpeg2 \
    libmad \
    hicolor-icon-theme

# Build the package
RUN makepkg -sif --noconfirm
RUN makepkg --printsrcinfo > .SRCINFO
