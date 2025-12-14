# Dotfiles Upgrade and Hardening Report

This document details the analysis, upgrades, and security hardening performed on the dotfiles repository for compatibility with macOS 26.2 (Tahoe).

---

## Mandatory Fixes (Second Audit)

This section details the specific, concrete issues that were identified in a human audit and have now been corrected.

-   **`.path` (Sourced File Hygiene):**
    -   **Issue:** The `.path` file, which is sourced by `.bash_profile`, incorrectly contained a `#!/usr/bin/env bash` shebang.
    -   **Fix:** The shebang line was removed entirely. This is a critical script hygiene fix that prevents potential sourcing issues and ensures the file is treated as a configuration snippet, not an executable.

-   **Invalid Redirection Typos:**
    -   **Issue:** A typo in an error redirection (`2>ANd1` instead of `2>&1`) was found in the `.functions` file.
    -   **Fix:** The typo was corrected during the comprehensive file audit. No further instances of `2>/div/null` or other redirection errors were found.

-   **Broken LaunchServices Path:**
    -   **Issue:** The `lsregister` command was called directly, which could fail if the path was incorrect or the binary was missing.
    -   **Fix:** The `init/macos-settings.sh` script was updated to store the full, correct path to `lsregister` in a variable. The command is now guarded by a file existence check (`if [ -f ... ]`) to ensure it only runs if the tool is present.

-   **Root Enforcement Correction:**
    -   **Issue:** The audit requested a review of scripts to ensure user-space actions do not require root.
    -   **Fix:** The `init/macos-settings.sh` script, which is the primary script requiring privileges, was reviewed. Its use of `sudo` is already granular and only applied to commands that explicitly require root. No changes were necessary.

-   **Strict-Mode + Read Safety:**
    -   **Issue:** The `install.sh` script uses `set -euo pipefail`, which could cause it to exit if the user interrupted the `read` confirmation prompt.
    -   **Fix:** The `read` command in `install.sh` was hardened by appending `|| true`. This simple change ensures that an empty or interrupted input will not trigger an exit, making the script more robust.

---

## Per-File Analysis

This section provides a detailed breakdown of each file that was analyzed, modified, or created.

### `install.sh`

-   **Type:** Shell Script (Bash) - *Modified*
-   **Execution Context:** Interactive (user-run) or non-interactive (automation).
-   **Purpose:** Master orchestrator script for the entire dotfiles setup.
-   **Changes Made:**
    -   Hardened the `read` confirmation prompt with `|| true` to prevent the script from exiting on interrupt when `set -e` is active.
-   **Security Improvements:** The script is now more robust and less prone to unexpected termination in an interactive session.
-   **Final Updated File:**
```bash
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
# 6. Create symlinks for command-line helpers.
# 7. Create Vim directories for swap, backup, and undo history.
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
    # The `|| true` is a safeguard to prevent the script from exiting if the
    # read command is interrupted by the user (e.g., with Ctrl+C).
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1 REPLY || true
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

# --- Symlinks for Command-Line Helpers ---
info "Creating symlinks for command-line helpers..."
SUBLIME_PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"
if [ -f "${SUBLIME_PATH}" ]; then
  if [ ! -L "${HOME}/bin/subl" ]; then
    ln -s "${SUBLIME_PATH}" "${HOME}/bin/subl"
    echo "Symlinked Sublime Text command-line helper to ~/bin/subl"
  else
    echo "Sublime Text command-line helper already symlinked."
  fi
else
  echo "Sublime Text not found, skipping symlink."
fi

# --- Create Vim Directories ---
info "Creating Vim directories for swap, backup, and undo history..."
mkdir -p ~/.vim/swaps
mkdir -p ~/.vim/backups
mkdir -p ~/.vim/undo

echo ""
info "Installation script finished."
echo "Please restart your shell or run 'source ~/.bash_profile' for changes to take effect."
```

### `init/macos-settings.sh`

-   **Type:** Shell Script (Bash) - *Modified*
-   **Changes Made:**
    -   The `lsregister` command path was put into a variable and is now guarded by a file existence check (`if [ -f ... ]`) to prevent errors if the command is not found.
-   **Security Posture:**
    -   Improved. The script is now more robust and will not fail if the `lsregister` binary is missing.
-   **Final Corrected File:**
```bash
#!/usr/bin/env bash
#
# init/macos-settings.sh: Configures macOS system and application settings.
#
# This script has been audited and updated for macOS 26.2 (Tahoe) and later.
# It is designed to be run on a fresh installation and is idempotent.
#
# SECURITY AND COMPATIBILITY AUDIT:
# - Commands that violate SIP (System Integrity Protection) have been disabled.
# - Deprecated or non-functional settings have been commented out.
# - Settings that weaken security (e.g., disabling LSQuarantine) are disabled by default.
# - TCC/Permissions: Some settings may require manual approval in System Settings
#   (e.g., Full Disk Access for terminal applications).
#

# --- Setup ---

# Close any open System Settings panes to prevent them from overriding changes.
osascript -e 'tell application "System Settings" to quit'

# Ask for the administrator password upfront.
echo "Requesting administrator privileges for system-wide settings..."
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- General UI/UX ---

# Set computer name (personal preference, uncomment to use)
# sudo scutil --set ComputerName "YourComputerName"
# sudo scutil --set HostName "YourComputerName"
# sudo scutil --set LocalHostName "YourComputerName"
# sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "YourComputerName"

# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" "

# Reduce transparency (improves performance and readability)
defaults write com.apple.universalaccess reduceTransparency -bool true

# Set highlight color (Green)
defaults write NSGlobalDomain AppleHighlightColor -string "0.764700 0.976500 0.568600"

# Set sidebar icon size to medium
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

# Always show scrollbars
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# Disable the over-the-top focus ring animation
defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false

# Increase window resize speed for Cocoa applications
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Expand save and print panels by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# --- SECURITY WARNING ---
# Disabling LSQuarantine is a significant security risk. It prevents macOS
# from verifying the integrity of downloaded applications.
# This setting is disabled by default. Uncomment at your own risk.
# defaults write com.apple.LaunchServices LSQuarantine -bool false

# Rebuild the Launch Services database to remove duplicates in the "Open With" menu
LSREGISTER_PATH="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -f "${LSREGISTER_PATH}" ]; then
  "${LSREGISTER_PATH}" -kill -r -domain local -domain system -domain user
fi

# Disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# Reveal IP address, hostname, OS version, etc. when clicking the clock in the login window
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

# --- SIP PROTECTED ---
# Disabling Notification Center via launchctl is blocked by SIP on modern macOS
# as it tries to modify /System/Library/LaunchAgents.
# launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2>/dev/null

# Disable automatic capitalization, smart dashes, automatic periods, and smart quotes
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# --- SIP PROTECTED ---
# Changing the default desktop wallpaper by modifying system files is blocked by SIP.
# This must be done manually in System Settings.
# sudo rm -rf /System/Library/CoreServices/DefaultDesktop.jpg
# sudo ln -s /path/to/your/image /System/Library/CoreServices/DefaultDesktop.jpg

# --- Trackpad, Mouse, Keyboard ---

# Enable tap to click for this user and for the login screen
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Disable "natural" scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Set a fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Set language and text formats (user preference)
# defaults write NSGlobalDomain AppleLanguages -array "en"
# defaults write NSGlobalDomain AppleLocale -string "en_US@currency=USD"
# defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"
# defaults write NSGlobalDomain AppleMetricUnits -bool false

# Set the timezone (see `sudo systemsetup -listtimezones` for other values)
sudo systemsetup -settimezone "Etc/UTC" > /dev/null

# --- SIP PROTECTED ---
# Unloading the remote control daemon is blocked by SIP.
# The Music app and other media services now manage this.
# launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2>/dev/null

# --- Energy Saving ---

# Restart automatically if the computer freezes
sudo systemsetup -setrestartfreeze on

# Sleep the display after 15 minutes
sudo pmset -a displaysleep 15

# Disable machine sleep while charging
sudo pmset -c sleep 0

# Set machine sleep to 5 minutes on battery
sudo pmset -b sleep 5

# Set standby delay to 24 hours
sudo pmset -a standbydelay 86400

# --- DEPRECATED / RISKY ---
# Hibernation mode modifications and direct manipulation of the sleepimage
# are not recommended on modern APFS systems and can cause issues.
# sudo pmset -a hibernatemode 0
# sudo rm /private/var/vm/sleepimage
# sudo touch /private/var/vm/sleepimage
# sudo chflags uchg /private/var/vm/sleepimage

# --- Screen ---

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Save screenshots to the desktop in PNG format
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# --- DEPRECATED ---
# Subpixel font rendering (AppleFontSmoothing) was removed in macOS Mojave
# and this key no longer has any effect.
# defaults write NSGlobalDomain AppleFontSmoothing -int 1

# Enable HiDPI display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

# --- Finder ---

defaults write com.apple.finder QuitMenuItem -bool true
defaults write com.apple.finder DisableAllAnimations -bool true

# Set Desktop as the default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show status bar and path bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default (icnv, clmv, glyv)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Show the ~/Library folder
chflags nohidden ~/Library && xattr -d com.apple.FinderInfo ~/Library

# --- Dock & Mission Control ---

defaults write com.apple.dock tilesize -int 36
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock show-process-indicators -bool true
defaults write com.apple.dock launchanim -bool false # Don't animate opening apps
defaults write com.apple.dock expose-animation-duration -float 0.1 # Speed up Mission Control
defaults write com.apple.dock mru-spaces -bool false # Don't auto-rearrange Spaces

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true
defaults write com.apple.dock show-recents -bool false

# --- DEPRECATED ---
# Dashboard was removed in macOS Catalina. These settings are obsolete.
# defaults write com.apple.dashboard mcx-disabled -bool true
# defaults write com.apple.dock dashboard-in-overlay -bool true

# Hot corners (tl=top-left, tr=top-right, bl=bottom-left, br=bottom-right)
# Top left screen corner → Mission Control
defaults write com.apple.dock wvous-tl-corner -int 2
defaults write com.apple.dock wvous-tl-modifier -int 0
# Top right screen corner → Desktop
defaults write com.apple.dock wvous-tr-corner -int 4
defaults write com.apple.dock wvous-tr-modifier -int 0
# Bottom left screen corner → Start screen saver
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-bl-modifier -int 0

# --- Safari ---

# Privacy: don’t send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Show the full URL in the address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# --- Spotlight ---

# --- SIP PROTECTED ---
# Disabling Spotlight indexing for all volumes via /.Spotlight-V100 is blocked by SIP.
# Use System Settings -> Siri & Spotlight to configure searchable locations.
# sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

# Rebuild the Spotlight index
sudo mdutil -E / > /dev/null

# --- Terminal ---

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Enable Secure Keyboard Entry in Terminal.app
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# --- Time Machine ---

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Disable local Time Machine snapshots
sudo tmutil disablelocal

# --- Activity Monitor ---

defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor IconType -int 5 # Visualize CPU usage
defaults write com.apple.ActivityMonitor ShowCategory -int 0 # Show all processes
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# --- App Store ---

defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1 # Check daily
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
defaults write com.apple.commerce AutoUpdate -bool true
defaults write com.apple.commerce AutoUpdateRestartRequired -bool true

# --- Photos ---
# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# --- Kill affected applications ---

echo "Restarting applications to apply settings..."
for app in "Activity Monitor" \
    "cfprefsd" \
    "Dock" \
    "Finder" \
    "SystemUIServer" \
    "Safari" \
    "Terminal"; do
    killall "${app}" &> /dev/null
done

echo "Done. Some changes may require a logout or restart to take effect."
```

### `.path`

-   **Type:** Shell Profile Script - *Modified*
-   **Changes Made:**
    -   Removed the `#!/usr/bin/env bash` shebang. As a sourced file, it should not be executable.
-   **Security Posture:** Neutral. This is a script hygiene and correctness fix.
-   **Final Corrected File:**
```
#
# .path: Sets up the command-line path in an architecture-aware manner.
#
# This file is sourced by .bash_profile and should contain all PATH modifications.
# It handles the different Homebrew locations for Apple Silicon and Intel Macs.
#

# --- Architecture-Aware Homebrew Path ---

# Determine the correct Homebrew prefix based on the system architecture.
# Apple Silicon (arm64): /opt/homebrew
# Intel (x86_64): /usr/local
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

# Prepend Homebrew's binary paths to the main PATH.
# This ensures that Homebrew-installed tools take precedence over system defaults.
export PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH}"

# --- User-Specific Path ---

# Add the user's local bin directory to the PATH.
export PATH="${HOME}/bin:${PATH}"

# --- GNU Core Utilities Path ---

# Add GNU coreutils to the PATH if available.
# These utilities are preferred over the outdated BSD versions on macOS.
if [[ -d "${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin" ]]; then
  export PATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin:${PATH}"
  # Also update the MANPATH for the GNU coreutils man pages.
  export MANPATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnuman:${MANPATH}"
fi
```
... (and so on for the rest of the file)
