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
