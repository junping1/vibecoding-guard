#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
app_name="Vibe Coding Guard.app"
old_app_name="Vibecoding Guard.app"
derived_data="$project_dir/build/DerivedData"
app_dir="$derived_data/Build/Products/Release/$app_name"
install_dir="$HOME/Applications/$app_name"
old_install_dir="$HOME/Applications/$old_app_name"
project_file="$project_dir/VibeCodingGuard.xcodeproj"
scheme_name="VibeCodingGuard"
executable_name="VibeCodingGuard"

cd "$project_dir"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$project_dir/project.yml"
elif [[ ! -d "$project_file" ]]; then
  echo "xcodegen is required to generate VibeCodingGuard.xcodeproj" >&2
  exit 1
fi

rm -rf "$derived_data"
xcodebuild \
  -project "$project_file" \
  -scheme "$scheme_name" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$derived_data" \
  -quiet \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  build

if [[ ! -d "$app_dir" ]]; then
  echo "Build succeeded, but $app_dir was not produced." >&2
  exit 1
fi

chmod +x "$app_dir/Contents/MacOS/$executable_name"
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
codesign --force --deep --sign - "$app_dir" >/dev/null

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$old_install_dir"
rm -rf "$install_dir"
ditto --norsrc --noqtn "$app_dir" "$install_dir"
cp "$project_dir/packaging/com.jpy.vibecodingguard.plist" "$HOME/Library/LaunchAgents/com.jpy.vibecodingguard.plist"

plutil -lint "$install_dir/Contents/Info.plist"
plutil -lint "$HOME/Library/LaunchAgents/com.jpy.vibecodingguard.plist"

echo "$install_dir"
