FROM brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD ./

# Install build dependencies.  Example for python-conda:
RUN yay -S --noconfirm \
  # micromamba \
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
  ccache \
  python-cmake>=3.18 \
  doctest \
  python-ninja \
  pybind11 \
  python-build \
  python-installer \
  python-scikit-build>=0.13 \
  python-setuptools>=42 \
  python-wheel

# Build the package
RUN makepkg -sif --noconfirm