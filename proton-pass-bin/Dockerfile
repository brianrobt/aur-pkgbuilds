FROM brianrobt/archlinux-aur-dev:latest

# Copy local AUR package files to the container
COPY --chown=builder:builder .SRCINFO PKGBUILD ./

# Update the system
USER root
RUN pacman -Syu --noconfirm

# Clone a copy of the most recent AUR package
RUN eval "$(ssh-agent -s)"
RUN ssh-add ~/.ssh/id_rsa
RUN git clone ssh://aur@aur.archlinux.org/proton-pass-bin.git

# Install build dependencies
USER builder

# Build the package
RUN makepkg -si --noconfirm
