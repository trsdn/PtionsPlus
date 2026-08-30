#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DEST="/Applications/Ptions+.app"
CONFIGURATION="${1:-debug}"
ENV_FILE="${RELEASE_ENV_FILE:-$PROJECT_DIR/.release.env}"
ENTITLEMENTS_FILE="$PROJECT_DIR/PtionsPlus/PtionsPlus.entitlements"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

IDENTITY="${CODE_SIGN_IDENTITY:-}"

find_latest_debug_app() {
  find "$HOME/Library/Developer/Xcode/DerivedData" \
    -type d \
    -path "*/Build/Products/Debug/Ptions+.app" \
    -print 2>/dev/null | while IFS= read -r path; do
      printf '%s\t%s\n' "$(stat -f '%m' "$path")" "$path"
    done | sort -rn | head -n 1 | cut -f2-
}

case "$CONFIGURATION" in
  debug)
    echo "Building latest Debug app..."
    xcodebuild \
      -project "$PROJECT_DIR/PtionsPlus.xcodeproj" \
      -scheme "Ptions+" \
      -configuration Debug \
      build >/dev/null
    APP_SOURCE="$(find_latest_debug_app)"
    ;;
  release)
    APP_SOURCE="$PROJECT_DIR/build/PtionsPlus.xcarchive/Products/Applications/Ptions+.app"
    ;;
  *)
    echo "Usage: $0 [debug|release]"
    exit 1
    ;;
esac

if [ ! -d "$APP_SOURCE" ]; then
  echo "Error: $APP_SOURCE not found."
  if [ "$CONFIGURATION" = "release" ]; then
    echo "Run scripts/sign-release.sh first or use: bash scripts/deploy.sh debug"
  fi
  exit 1
fi

pkill -x "Ptions+" || true
rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" /Applications/

if [ -n "$IDENTITY" ]; then
  echo "Re-signing deployed app with stable identity..."
  codesign \
    --force \
    --deep \
    --sign "$IDENTITY" \
    --entitlements "$ENTITLEMENTS_FILE" \
    --timestamp \
    --options runtime \
    --generate-entitlement-der \
    "$APP_DEST"
else
  echo "No CODE_SIGN_IDENTITY configured. Deployed app stays ad-hoc signed, so Accessibility permission may be requested again."
fi

xattr -cr "$APP_DEST"
open "$APP_DEST"

echo "Deployed from: $APP_SOURCE"
echo "Deployed to: $APP_DEST"