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
sign_identity="${VCG_CODE_SIGN_IDENTITY:-}"
sign_team=""
preferred_sign_team="5W738VH83V"

cd "$project_dir"

if [[ -z "$sign_identity" ]]; then
  while IFS= read -r candidate_identity; do
    cert_pem="$(security find-certificate -c "$candidate_identity" -p 2>/dev/null || true)"
    if [[ -z "$cert_pem" ]]; then
      continue
    fi
    if ! printf '%s\n' "$cert_pem" | openssl x509 -checkend 0 -noout >/dev/null 2>&1; then
      continue
    fi
    candidate_team="$(printf '%s\n' "$cert_pem" | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU=\([^,]*\).*/\1/p')"
    if [[ "$candidate_team" == "$preferred_sign_team" ]]; then
      sign_identity="$candidate_identity"
      break
    fi
  done < <(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development:/ && $0 !~ /CSSMERR/ { print $2 }')
fi

if [[ -z "$sign_identity" ]]; then
  while IFS= read -r candidate_identity; do
    cert_pem="$(security find-certificate -c "$candidate_identity" -p 2>/dev/null || true)"
    if [[ -z "$cert_pem" ]]; then
      continue
    fi
    if ! printf '%s\n' "$cert_pem" | openssl x509 -checkend 0 -noout >/dev/null 2>&1; then
      continue
    fi
    sign_identity="$candidate_identity"
    break
  done < <(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development:/ && $0 !~ /CSSMERR/ { print $2 }')
fi

if [[ -n "$sign_identity" ]]; then
  sign_team="$(
    security find-certificate -c "$sign_identity" -p 2>/dev/null |
      openssl x509 -noout -subject 2>/dev/null |
      sed -n 's/.*OU=\([^,]*\).*/\1/p'
  )"
fi

development_team_arg=()
if [[ -n "$sign_team" ]]; then
  development_team_arg=(DEVELOPMENT_TEAM="$sign_team")
fi

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
  CODE_SIGN_IDENTITY="${sign_identity:-"-"}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  "${development_team_arg[@]}" \
  build

if [[ ! -d "$app_dir" ]]; then
  echo "Build succeeded, but $app_dir was not produced." >&2
  exit 1
fi

for localization_dir in "$project_dir"/Resources/*.lproj(N); do
  ditto --norsrc --noqtn "$localization_dir" "$app_dir/Contents/Resources/$(basename "$localization_dir")"
done

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
if [[ -n "$sign_identity" ]]; then
  codesign --force --deep --sign "$sign_identity" "$app_dir" >/dev/null
else
  codesign --force --deep --sign - "$app_dir" >/dev/null
fi

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$old_install_dir"
rm -rf "$install_dir"
ditto --norsrc --noqtn "$app_dir" "$install_dir"
cp "$project_dir/packaging/com.jpy.vibecodingguard.plist" "$HOME/Library/LaunchAgents/com.jpy.vibecodingguard.plist"

plutil -lint "$install_dir/Contents/Info.plist"
plutil -lint "$HOME/Library/LaunchAgents/com.jpy.vibecodingguard.plist"

if [[ -n "$sign_identity" ]]; then
  echo "Signed with: $sign_identity"
else
  echo "Signed ad-hoc. Accessibility permission may need to be reset after rebuilds."
fi
echo "$install_dir"
