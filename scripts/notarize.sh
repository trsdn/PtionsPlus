#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${RELEASE_ENV_FILE:-$PROJECT_DIR/.release.env}"
APP="$PROJECT_DIR/build/PtionsPlus.xcarchive/Products/Applications/Ptions+.app"
SUBMISSION_ZIP="$PROJECT_DIR/build/notarization/Ptions+-submission.zip"
ZIP="$PROJECT_DIR/dist/Ptions+.zip"
DMG="$PROJECT_DIR/dist/Ptions+.dmg"
DMG_STAGING="$PROJECT_DIR/build/dmg-staging"
DMG_VOLUME_NAME="Ptions+"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

KEYCHAIN_PROFILE="${NOTARY_PROFILE:-PtionsPlus}"

if [ ! -d "$APP" ]; then
  echo "Error: $APP not found. Run scripts/sign-release.sh first."
  exit 1
fi

if [ ! -f "$SUBMISSION_ZIP" ]; then
  echo "Error: $SUBMISSION_ZIP not found. Run scripts/sign-release.sh first."
  exit 1
fi

submit_for_notarization() {
  local artifact="$1"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$KEYCHAIN_PROFILE" \
      --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$artifact" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --wait
  else
    echo "Error: set NOTARY_PROFILE or APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD."
    exit 1
  fi
}

FLAGS=$(codesign -dv "$APP" 2>&1 | grep "^CodeDirectory" || true)
if ! echo "$FLAGS" | grep -q "runtime"; then
  echo "Error: app is not signed with Hardened Runtime."
  exit 1
fi

echo "Submitting app for notarization..."
submit_for_notarization "$SUBMISSION_ZIP"

echo "Stapling and validating app..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose "$APP"

echo "Creating final ZIP from stapled app..."
mkdir -p "$PROJECT_DIR/dist"
rm -f "$ZIP" "$DMG" "$DMG.sha256"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Creating DMG from stapled app..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto "$APP" "$DMG_STAGING/Ptions+.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  echo "Error: CODE_SIGN_IDENTITY is required to sign the DMG."
  exit 1
fi
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
codesign --verify --verbose=2 "$DMG"
hdiutil verify "$DMG"

echo "Submitting DMG for notarization..."
submit_for_notarization "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

(
  cd "$PROJECT_DIR/dist"
  shasum -a 256 "Ptions+.dmg" > "Ptions+.dmg.sha256"
)

scripts/verify-release-artifacts.sh

echo "Created final notarized artifacts:"
echo "  $ZIP"
echo "  $DMG"
echo "  $DMG.sha256"
