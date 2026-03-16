#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${RELEASE_ENV_FILE:-$PROJECT_DIR/.release.env}"
APP="$PROJECT_DIR/build/PtionsPlus.xcarchive/Products/Applications/Ptions+.app"
ZIP="$PROJECT_DIR/dist/Ptions+.zip"
DMG="$PROJECT_DIR/dist/Ptions+.dmg"

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

if [ ! -f "$ZIP" ]; then
    echo "Error: $ZIP not found. Run scripts/sign-release.sh first."
    exit 1
fi

if [ ! -f "$DMG" ]; then
    echo "Error: $DMG not found. Run scripts/sign-release.sh first."
    exit 1
fi

FLAGS=$(codesign -dv "$APP" 2>&1 | grep "^CodeDirectory" || true)
if ! echo "$FLAGS" | grep -q "runtime"; then
    echo "Error: App is not signed with Hardened Runtime. Run scripts/sign-release.sh first."
    exit 1
fi

echo "Submitting to Apple notarization service..."
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "Submitting DMG to Apple notarization service..."
xcrun notarytool submit "$DMG" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP"
xcrun stapler staple "$DMG"

echo "Verifying Gatekeeper assessment..."
spctl --assess --type execute --verbose "$APP" 2>&1
spctl --assess --type open --context context:primary-signature --verbose "$DMG" 2>&1

echo "Done. Ptions+.app and Ptions+.dmg are notarized and stapled."
