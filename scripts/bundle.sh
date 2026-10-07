#!/bin/sh
# Builds dist/PullJoy.app (Apple Silicon) from the Swift package, plus a zip and a dmg of it.
#
#   PULLJOY_GITHUB_CLIENT_ID  OAuth App client ID baked into Info.plist (see README)
#   PULLJOY_GITHUB_CLIENT_SECRET  its client secret, baked in the same way
#   SIGN_IDENTITY              codesign identity, e.g. "Developer ID Application: Name (TEAMID)"; ad hoc ("-") when unset
#   NOTARY_PROFILE             notarytool keychain profile; notarizes and staples the app and the dmg when set
#   BUNDLE_ID                  defaults to com.noma4i.pulljoy
#   PULLJOY_UPDATE_REPOSITORY owner/repo whose GitHub releases are checked for updates; none when unset
set -e
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
BUNDLE_ID="${BUNDLE_ID:-com.noma4i.pulljoy}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APP="dist/PullJoy.app"
ZIP="dist/PullJoy-$VERSION.zip"
DMG="dist/PullJoy-$VERSION.dmg"

if [ -n "$NOTARY_PROFILE" ] && [ "$SIGN_IDENTITY" = "-" ]; then
  echo "bundle: NOTARY_PROFILE needs SIGN_IDENTITY: Apple rejects ad hoc signatures" >&2
  exit 1
fi

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/PullJoy"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PullJoy"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PullJoy</string>
  <key>CFBundleDisplayName</key><string>PullJoy</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>PullJoy</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
  <key>PullJoyGitHubClientID</key><string>${PULLJOY_GITHUB_CLIENT_ID:-}</string>
  <key>PullJoyGitHubClientSecret</key><string>${PULLJOY_GITHUB_CLIENT_SECRET:-}</string>
  <key>PullJoyUpdateRepository</key><string>${PULLJOY_UPDATE_REPOSITORY:-}</string>
</dict>
</plist>
PLIST

sign() {
  if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$1"
  else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$1"
  fi
}

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$2"
}

sign "$APP"
codesign --verify --strict "$APP"

mkdir -p dist
if [ -n "$NOTARY_PROFILE" ]; then
  ditto -c -k --keepParent "$APP" dist/notarize.zip
  notarize dist/notarize.zip "$APP"
  rm -f dist/notarize.zip
fi

rm -f "$ZIP" "$DMG"
ditto -c -k --keepParent "$APP" "$ZIP"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname PullJoy -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

if [ "$SIGN_IDENTITY" != "-" ]; then
  sign "$DMG"
fi
if [ -n "$NOTARY_PROFILE" ]; then
  notarize "$DMG" "$DMG"
fi

echo "Built $APP ($VERSION), $ZIP and $DMG"
