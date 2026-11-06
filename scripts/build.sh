#!/bin/zsh
set -eu
task_root="${0:A:h:h}"
app_path="$task_root/dist/端口管家.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
xcrun swift "$task_root/scripts/icon.swift" "$task_root/dist/AppIcon.iconset"
/usr/bin/iconutil -c icns "$task_root/dist/AppIcon.iconset" -o "$task_root/dist/AppIcon.icns"
xcrun swiftc -swift-version 5 -O -parse-as-library \
  "$task_root/Sources/PortService.swift" "$task_root/Sources/ProcessOrigin.swift" "$task_root/Sources/PortManagerApp.swift" \
  -target arm64-apple-macosx13.0 -framework SwiftUI -framework AppKit \
  -o "$app_path/Contents/MacOS/PortManager"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>PortManager</string>
  <key>CFBundleIdentifier</key><string>local.tpc.port-manager</string>
  <key>CFBundleName</key><string>端口管家</string>
  <key>CFBundleDisplayName</key><string>端口管家</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.2.0</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
cp "$task_root/README.md" "$app_path/Contents/Resources/README.md"
cp "$task_root/LICENSE" "$app_path/Contents/Resources/LICENSE"
rm -f "$app_path/Contents/Resources/THIRD_PARTY_NOTICES.md"
if [[ -f "$task_root/dist/AppIcon.icns" ]]; then
  cp "$task_root/dist/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
fi
codesign --force --deep --sign - "$app_path"
printf 'Built: %s\n' "$app_path"
