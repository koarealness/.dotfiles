#!/usr/bin/env bash

#
# install.sh: Main installation script for the dotfiles repository
#
# This script is designed to be the single entry point for setting up the
# dotfiles environment. It is idempotent and can be run safely multiple times.
# It handles different architectures (Apple Silicon, Intel) and ensures that
# interactive prompts are only shown when a TTY is present.
#
# The script will:
# 1. Detect the system architecture and set up Homebrew accordingly.
# 2. Install Homebrew if it is not already installed.
# 3. Install all the packages and applications from brew.sh.
# 4. Sync the dotfiles to the home directory.
# 5. Apply macOS settings from .osx.
#

set -euo pipefail

# --- Helper Functions ---
info() {
  printf "\n\033[1;34m%s\033[0m\n" "$1"
}

# --- Architecture and Homebrew Setup ---
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi
HOMEBREW_BIN="${HOMEBREW_PREFIX}/bin/brew"

# --- Main Script ---

info "Starting dotfiles installation..."

# Move to the script's directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# --- Git Update ---
info "Updating repository from git..."
if git pull origin main; then
  echo "Repository updated successfully."
else
  echo "Could not update repository. Continuing with local version."
fi

# --- Homebrew Installation ---
info "Setting up Homebrew..."
if [[ ! -f "$HOMEBREW_BIN" ]]; then
  info "Homebrew not found. Installing..."
  # Run the official Homebrew installer non-interactively
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  info "Homebrew is already installed."
fi

# --- Package Installation (via brew.sh) ---
info "Running brew.sh to install packages..."
# Pass all arguments from this script to brew.sh
./brew.sh "$@"

# --- Dotfiles Sync ---
sync_dotfiles() {
  info "Syncing dotfiles to home directory..."
  rsync -avh --no-perms \
    --exclude ".git/" \
    --exclude ".DS_Store" \
    --exclude "*.sh" \
    --exclude "README.md" \
    --exclude "LICENSE-MIT.txt" \
    --exclude "init/" \
    --exclude ".vim/" \
    . ~
  echo "Dotfiles sync complete."
}

if [[ "$*" == *"--force"* || "$*" == *"-f"* ]]; then
  sync_dotfiles
else
  if [ -t 1 ]; then
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sync_dotfiles
    else
      echo "Skipping dotfiles sync."
    fi
  else
    echo "Running non-interactively. Use --force to sync dotfiles."
  fi
fi

# --- macOS Settings ---
info "Applying macOS settings from .osx..."
source .osx

echo ""
info "Installation script finished."
echo "Please restart your shell or run 'source ~/.bash_profile' for changes to take effect."
