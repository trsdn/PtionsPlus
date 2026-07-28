#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP="${APP_PATH:-$PROJECT_DIR/build/PtionsPlus.xcarchive/Products/Applications/Ptions+.app}"
ZIP="${ZIP_PATH:-$PROJECT_DIR/dist/Ptions+.zip}"
DMG="${DMG_PATH:-$PROJECT_DIR/dist/Ptions+.dmg}"
CHECKSUM="$DMG.sha256"
TEMP_DIR=$(mktemp -d /tmp/ptionsplus-artifacts.XXXXXX)
MOUNT_POINT="$TEMP_DIR/mount"
DMG_ATTACHED=0

cleanup() {
  if [ "$DMG_ATTACHED" -eq 1 ]; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

for path in "$APP" "$ZIP" "$DMG" "$CHECKSUM"; do
  if [ ! -e "$path" ]; then
    echo "Error: required artifact not found: $path"
    exit 1
  fi
done

verify_app() {
  local app="$1"
  codesign --verify --deep --strict --verbose=2 "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose "$app"
}

app_cdhash() {
  codesign -d --verbose=4 "$1" 2>&1 | awk -F= '/^CDHash=/{hash=$2} END{print hash}'
}

verify_app "$APP"
REFERENCE_EXECUTABLE_HASH=$(shasum -a 256 "$APP/Contents/MacOS/Ptions+" | awk '{print $1}')
REFERENCE_CDHASH=$(app_cdhash "$APP")

ZIP_DIR="$TEMP_DIR/zip"
mkdir -p "$ZIP_DIR"
ditto -x -k "$ZIP" "$ZIP_DIR"
ZIP_APP="$ZIP_DIR/Ptions+.app"
verify_app "$ZIP_APP"
ZIP_EXECUTABLE_HASH=$(shasum -a 256 "$ZIP_APP/Contents/MacOS/Ptions+" | awk '{print $1}')
ZIP_CDHASH=$(app_cdhash "$ZIP_APP")
if [ "$ZIP_EXECUTABLE_HASH" != "$REFERENCE_EXECUTABLE_HASH" ] \
  || [ "$ZIP_CDHASH" != "$REFERENCE_CDHASH" ]; then
  echo "Error: ZIP contains a different signed app."
  exit 1
fi

mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT" -quiet
DMG_ATTACHED=1
DMG_APP="$MOUNT_POINT/Ptions+.app"
verify_app "$DMG_APP"
DMG_EXECUTABLE_HASH=$(shasum -a 256 "$DMG_APP/Contents/MacOS/Ptions+" | awk '{print $1}')
DMG_CDHASH=$(app_cdhash "$DMG_APP")
if [ "$DMG_EXECUTABLE_HASH" != "$REFERENCE_EXECUTABLE_HASH" ] \
  || [ "$DMG_CDHASH" != "$REFERENCE_CDHASH" ]; then
  echo "Error: DMG contains a different signed app."
  exit 1
fi
hdiutil detach "$MOUNT_POINT" -quiet
DMG_ATTACHED=0

spctl --assess --type open --context context:primary-signature --verbose "$DMG"

CHECK_DIR="$TEMP_DIR/checksum"
mkdir -p "$CHECK_DIR"
cp "$DMG" "$CHECKSUM" "$CHECK_DIR/"
(
  cd "$CHECK_DIR"
  shasum -a 256 -c "$(basename "$CHECKSUM")"
)

echo "Release artifacts verified successfully."
