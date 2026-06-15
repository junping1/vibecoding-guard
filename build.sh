#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
build_dir="${TMPDIR:-/tmp}/vibecodingguard-build"
app_name="Vibecoding Guard.app"
app_dir="$build_dir/$app_name"
install_dir="$HOME/Applications/$app_name"

rm -rf "$build_dir"
mkdir -p "$app_dir/Contents/MacOS"

export MACOSX_DEPLOYMENT_TARGET=14.0

swiftc -O \
  -target arm64-apple-macos14.0 \
  -framework AppKit \
  -framework Foundation \
  -framework UserNotifications \
  "$project_dir/Sources/VibecodingGuard/main.swift" \
  -o "$app_dir/Contents/MacOS/VibecodingGuard"

cp "$project_dir/packaging/Info.plist" "$app_dir/Contents/Info.plist"
chmod +x "$app_dir/Contents/MacOS/VibecodingGuard"
xattr -cr "$app_dir" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$app_dir" 2>/dev/null || true
sleep 1
xattr -cr "$app_dir" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$app_dir" 2>/dev/null || true
find "$app_dir" -exec xattr -c {} + 2>/dev/null || true
find "$app_dir" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
find "$app_dir" -exec xattr -d 'com.apple.fileprovider.fpfs#P' {} + 2>/dev/null || true
codesign --force --deep --sign - "$app_dir"

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$install_dir"
ditto --norsrc --noqtn "$app_dir" "$install_dir"
cp "$project_dir/packaging/com.jpy.vibecodingguard.plist" "$HOME/Library/LaunchAgents/com.jpy.vibecodingguard.plist"

plutil -lint "$install_dir/Contents/Info.plist"
plutil -lint "$HOME/Library/LaunchAgents/com.jpy.vibecodingguard.plist"

echo "$install_dir"
