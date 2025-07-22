# Specify target platform architecture
# Use linux/amd64 for x86_64 systems, linux/arm64 for ARM64 systems
# Uncomment the appropriate line for your target architecture:
# FROM --platform=linux/amd64 brianrobt/archlinux-aur-dev:latest
FROM --platform=linux/arm64 brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD *.patch ./

# Update the system to resolve 404 errors for micromamba dependencies, libsolv and nss
USER root
RUN pacman -Syu --noconfirm

# Install build dependencies.  Example for python-conda:
USER builder
RUN yay -S --noconfirm \
  python \
  fmt \
  libsolv \
  reproc \
  yaml-cpp \
  simdjson \
  cli11 \
  spdlog \
  tl-expected \
  nlohmann-json \
  cmake \
  pybind11

# Build the package
RUN makepkg -sif --noconfirm
