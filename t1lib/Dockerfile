# Specify target platform architecture
# Use linux/amd64 for x86_64 systems, linux/arm64 for ARM64 systems
# Uncomment the appropriate line for your target architecture:
# FROM --platform=linux/amd64 brianrobt/archlinux-aur-dev:latest
FROM --platform=linux/arm64 brianrobt/archlinux-aur-dev:latest

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

# # Copy the updated .SRCINFO and PKGBUILD files back to the host
# # This requires the container to be run with a volume mount
# # Example: docker run -v $(pwd):/workspace -w /workspace <image>
# COPY .SRCINFO PKGBUILD /workspace/