# Specify target platform architecture
# Use linux/amd64 for x86_64 systems, linux/arm64 for ARM64 systems
# Uncomment the appropriate line for your target architecture:
# FROM --platform=linux/amd64 brianrobt/archlinux-aur-dev:latest
FROM --platform=linux/arm64 brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD ./

# Update the system to resolve 404 errors for micromamba dependencies, libsolv and nss
USER root
RUN pacman -Syu --noconfirm

# Install build dependencies
USER builder
RUN yay -S --noconfirm \
    python \
    python-hatch-vcs \
    python-build \
    python-installer \
    python-wheel \
    python-boltons \
    micromamba

# Build the package
RUN makepkg -sif --noconfirm

# Test that the package was installed correctly
RUN python -c "import conda_libmamba_solver; print('Package successfully installed')"
