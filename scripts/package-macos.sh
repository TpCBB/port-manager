#!/bin/zsh
set -eu
task_root="${0:A:h:h}"
app_path="$task_root/dist/端口管家.app"

"$task_root/scripts/build.sh"
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
image_path="$task_root/dist/PortManager-$app_version-mac-arm64.dmg"
staging_path=$(/usr/bin/mktemp -d "$task_root/dist/dmg-stage.XXXXXX")
trap '/bin/rm -rf "$staging_path"' EXIT

/usr/bin/ditto "$app_path" "$staging_path/端口管家.app"
/bin/ln -s /Applications "$staging_path/Applications"
/usr/bin/hdiutil create -volname '端口管家' -srcfolder "$staging_path" \
  -format UDZO -ov "$image_path"
/usr/bin/hdiutil verify "$image_path"
(
  cd "$task_root/dist"
  /usr/bin/shasum -a 256 "${image_path:t}" > "${image_path:t}.sha256"
)
printf 'Release package: %s\n' "$image_path"
