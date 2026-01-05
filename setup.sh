#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v rsync >/dev/null 2>&1; then
  echo "Error: rsync is required for syncing dotfiles; please install it and re-run." >&2
  exit 1
fi

echo "Running bootstrap to sync dotfiles into \$HOME..."
(
  cd "$REPO_ROOT"
  set -- -f
  # shellcheck disable=SC1091
  source "$REPO_ROOT/bootstrap.sh"
)

if [[ "${RUN_BREW:-0}" == "1" ]]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew packages from brew.sh..."
    bash "$REPO_ROOT/brew.sh"
  else
    echo "Homebrew not found; skipping brew.sh. Install Homebrew or omit RUN_BREW=1 to silence this message."
  fi
else
  echo "Skipping brew.sh (set RUN_BREW=1 to enable)."
fi

echo "Dotfiles setup complete."
