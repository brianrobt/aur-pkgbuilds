#!/bin/bash

# setup-aur-ssh.sh - Generate and setup AUR SSH keys for GitHub Actions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_step "AUR SSH Key Setup for GitHub Actions"
echo

# Check if key already exists
if [ -f ~/.ssh/aur_key ]; then
    print_warning "AUR SSH key already exists at ~/.ssh/aur_key"
    read -p "Do you want to generate a new key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Using existing key"
    else
        print_status "Backing up existing key..."
        mv ~/.ssh/aur_key ~/.ssh/aur_key.backup
        mv ~/.ssh/aur_key.pub ~/.ssh/aur_key.pub.backup
    fi
fi

# Generate SSH key
print_step "Generating SSH key pair..."
ssh-keygen -t ed25519 -C "github-actions@aur" -f ~/.ssh/aur_key -N ""

print_status "SSH key generated successfully"
echo

# Display public key
print_step "Public Key (add this to your AUR account):"
echo
cat ~/.ssh/aur_key.pub
echo

# Display private key
print_step "Private Key (add this to GitHub secrets as AUR_SSH_PRIVATE_KEY):"
echo
cat ~/.ssh/aur_key
echo

print_step "Next Steps:"
echo
echo "1. Copy the public key above and add it to your AUR account:"
echo "   - Go to https://aur.archlinux.org/account/"
echo "   - Add the SSH key to your account"
echo
echo "2. Copy the private key above and add it to GitHub secrets:"
echo "   - Go to your GitHub repository settings"
echo "   - Navigate to Secrets and variables > Actions"
echo "   - Add a new secret named 'AUR_SSH_PRIVATE_KEY'"
echo "   - Paste the private key content"
echo
echo "3. Add your AUR username as a secret:"
echo "   - Add another secret named 'AUR_USERNAME'"
echo "   - Set the value to your AUR username"
echo

print_status "Setup completed successfully!"