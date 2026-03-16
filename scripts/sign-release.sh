#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${RELEASE_ENV_FILE:-$PROJECT_DIR/.release.env}"
ARCHIVE_PATH="$PROJECT_DIR/build/PtionsPlus.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Ptions+.app"
ZIP_PATH="$PROJECT_DIR/dist/Ptions+.zip"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

TEAM_ID="${TEAM_ID:-G69Z5BNY97}"
IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: Torsten Mahr ($TEAM_ID)}"

cd "$PROJECT_DIR"
mkdir -p build dist
rm -rf "$ARCHIVE_PATH"
rm -f "$ZIP_PATH"

echo "Building signed release archive..."
xcodebuild \
  -project PtionsPlus.xcodeproj \
  -scheme "Ptions+" \
  -configuration Release \
  archive \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

echo "Verifying signature..."
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | tail -n 20

echo "Creating notarization ZIP..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created: $APP_PATH"
echo "Created: $ZIP_PATH"
