#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${RELEASE_ENV_FILE:-$PROJECT_DIR/.release.env}"
ARCHIVE_PATH="$PROJECT_DIR/build/PtionsPlus.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Ptions+.app"
ZIP_PATH="$PROJECT_DIR/dist/Ptions+.zip"

if [ -f "$ENV_FILE" ]; then
  echo "Loading release config from $ENV_FILE"
  set -a
  . "$ENV_FILE"
  set +a
else
  echo "No release env file found at $ENV_FILE, using current shell environment"
fi

TEAM_ID="${TEAM_ID:-}"
IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [ -z "$TEAM_ID" ]; then
  echo "Error: TEAM_ID is not set. Configure it in $ENV_FILE or export TEAM_ID."
  exit 1
fi

if [ -z "$IDENTITY" ]; then
  echo "Error: CODE_SIGN_IDENTITY is not set. Configure it in $ENV_FILE or export CODE_SIGN_IDENTITY."
  exit 1
fi

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
