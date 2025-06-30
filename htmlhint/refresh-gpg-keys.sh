#!/bin/bash

# Remove old keyrings
sudo rm -rf /etc/pacman.d/gnupg

# Reinitialize keyring
sudo pacman-key --init

# Populate with Arch Linux keys
sudo pacman-key --populate archlinux

# Update the keyring package
sudo pacman -S --noconfirm archlinux-keyring