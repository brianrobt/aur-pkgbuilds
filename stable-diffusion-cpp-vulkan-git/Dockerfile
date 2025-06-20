FROM brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD 001-fix-shared-lib-install.diff ./

# Update the system to resolve 404 errors for micromamba dependencies, libsolv and nss
USER root
RUN pacman -Syu --noconfirm

# Install build dependencies.  Example for python-conda:
USER builder
RUN yay -S --noconfirm \
    vulkan-icd-loader \
    vulkan-validation-layers \
    gcc-libs \
    glibc \
    cmake \
    git \
    vulkan-headers \
    shaderc

RUN makepkg -si --noconfirm