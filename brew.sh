#!/usr/bin/env bash
#
# brew.sh: Installs and configures Homebrew and its packages.
#
# This script is designed to be idempotent and architecture-aware.
# It supports both Apple Silicon (arm64) and Intel (x86_64) Macs.
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

info "Detected architecture: ${ARCH}"
info "Homebrew prefix set to: ${HOMEBREW_PREFIX}"

# --- Package Installation ---
install_packages() {
  info "Updating Homebrew and installing packages..."
  "${HOMEBREW_BIN}" update
  "${HOMEBREW_BIN}" upgrade

  # GNU core utilities
  "${HOMEBREW_BIN}" install coreutils

  # Symlink for sha256sum if it doesn't exist
  if [[ ! -L "${HOMEBREW_PREFIX}/bin/sha256sum" ]]; then
    ln -s "${HOMEBREW_PREFIX}/bin/gsha256sum" "${HOMEBREW_PREFIX}/bin/sha256sum"
  fi

  # Other useful utilities
  "${HOMEBREW_BIN}" install moreutils findutils gnu-sed bash bash-completion2

  # Networking tools
  "${HOMEBREW_BIN}" install wget nmap socat dns2tcp tcpflow tcpreplay tcptrace ucspi-tcp

  # Security and PGP
  "${HOMEBREW_BIN}" install gnupg

  # More recent versions of macOS tools
  "${HOMEBREW_BIN}" install vim grep openssh screen gmp

  # PHP is commented out as the core formula is often not desired.
  # Consider 'brew tap shivammathur/php' and 'brew install shivammathur/php/php@8.1'
  # "${HOMEBREW_BIN}" install php

  # Font tools
  "${HOMEBREW_BIN}" tap bramstein/webfonttools
  "${HOMEBREW_BIN}" install sfnt2woff sfnt2woff-zopfli woff2

  # CTF tools
  "${HOMEBREW_BIN}" install aircrack-ng bfg binutils binwalk cifer dex2jar fcrackzip foremost hashpump hydra john knock netpbm pngcheck sqlmap xpdf xz

  # Other useful binaries
  "${HOMEBREW_BIN}" install ack git git-lfs gs imagemagick lua lynx p7zip pigz pv rename rlwrap ssh-copy-id tree vbindiff zopfli

  info "Cleaning up outdated versions..."
  "${HOMEBREW_BIN}" cleanup
}

# --- Change Shell ---
change_shell() {
  info "Changing default shell to Homebrew Bash..."
  local brew_bash="${HOMEBREW_PREFIX}/bin/bash"

  if ! grep -q "${brew_bash}" /etc/shells; then
    info "Adding Homebrew Bash to /etc/shells..."
    echo "${brew_bash}" | sudo tee -a /etc/shells
  fi

  if [[ "${SHELL}" != "${brew_bash}" ]]; then
    if chsh -s "${brew_bash}"; then
      echo "Shell changed successfully. Please open a new terminal."
    else
      echo "Failed to change shell. Please run 'chsh -s ${brew_bash}' manually." >&2
    fi
  else
    echo "Homebrew Bash is already the default shell."
  fi
}

# --- Main Logic ---
install_packages

# Handle shell change request
if [[ "$*" == *"--change-shell"* ]]; then
  if [ -t 1 ]; then # Check for interactive terminal
    change_shell
  else
    echo "Cannot change shell non-interactively."
    echo "Please run the following command manually:"
    echo "  chsh -s ${HOMEBREW_PREFIX}/bin/bash"
  fi
else
  echo ""
  info "To change your default shell to Homebrew Bash, run this script with the --change-shell flag."
fi

info "Homebrew script finished."
