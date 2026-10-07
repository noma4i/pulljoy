#!/bin/sh
# Tests, builds, signs with Developer ID, notarizes and publishes the release for the version in VERSION.
# The signing key and the notarytool credentials stay in the login keychain; nothing secret goes to GitHub.
#
#   SIGN_IDENTITY              defaults to the Developer ID Application identity of this Mac
#   NOTARY_PROFILE             notarytool keychain profile, defaults to clipmoar
#   PULLJOY_GITHUB_CLIENT_ID      OAuth App client ID baked into Info.plist
#   PULLJOY_GITHUB_CLIENT_SECRET  its secret. Both default to the login keychain item "pulljoy-oauth"
#                                  (accounts "client-id" and "client-secret").
set -e
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
TAG="v$VERSION"
export SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Alexander Tsirel (89QF7X66FR)}"
export NOTARY_PROFILE="${NOTARY_PROFILE:-clipmoar}"
export PULLJOY_GITHUB_CLIENT_ID="${PULLJOY_GITHUB_CLIENT_ID:-$(security find-generic-password -s pulljoy-oauth -a client-id -w 2>/dev/null || true)}"
export PULLJOY_GITHUB_CLIENT_SECRET="${PULLJOY_GITHUB_CLIENT_SECRET:-$(security find-generic-password -s pulljoy-oauth -a client-secret -w 2>/dev/null || true)}"
[ -n "$PULLJOY_GITHUB_CLIENT_ID" ] && [ -n "$PULLJOY_GITHUB_CLIENT_SECRET" ] || { echo "release: no OAuth App client ID and secret" >&2; exit 1; }

[ -z "$(git status --porcelain)" ] || { echo "release: the working tree is not clean" >&2; exit 1; }
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { echo "release: not on main" >&2; exit 1; }
REPO="$(git remote get-url origin | sed -E 's#.*github.com[:/]##; s#\.git$##')"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then echo "release: $TAG already exists" >&2; exit 1; fi

./scripts/test.sh
swift format lint --strict -r Sources Tests
swiftlint lint --strict --quiet
./scripts/bundle.sh

spctl --assess --type execute --verbose=2 dist/PullJoy.app
xcrun stapler validate dist/PullJoy.app
xcrun stapler validate "dist/PullJoy-$VERSION.dmg"

git push origin main
gh release create "$TAG" "dist/PullJoy-$VERSION.zip" "dist/PullJoy-$VERSION.dmg" \
  --repo "$REPO" --target main --title "PullJoy $VERSION" --generate-notes
echo "Published $TAG"
