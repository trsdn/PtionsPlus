#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/PtionsPlus.xcodeproj/project.pbxproj"
APP_PATH=""
TAG="${RELEASE_TAG:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--tag vX.Y.Z] [--app /path/to/Ptions+.app]"
      exit 1
      ;;
  esac
done

MARKETING_VERSION=$(grep -m1 'MARKETING_VERSION = ' "$PROJECT_FILE" | sed 's/.*= //; s/;//')
BUILD_VERSION=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT_FILE" | sed 's/.*= //; s/;//')

if [[ ! "$MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid MARKETING_VERSION '$MARKETING_VERSION'."
  exit 1
fi

if [[ ! "$BUILD_VERSION" =~ ^[0-9]+$ ]]; then
  echo "Error: invalid CURRENT_PROJECT_VERSION '$BUILD_VERSION'."
  exit 1
fi

if [ -n "$TAG" ]; then
  if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: release tag '$TAG' must match vX.Y.Z."
    exit 1
  fi
  if [ "${TAG#v}" != "$MARKETING_VERSION" ]; then
    echo "Error: tag '$TAG' does not match MARKETING_VERSION '$MARKETING_VERSION'."
    exit 1
  fi
fi

if [ -n "$APP_PATH" ]; then
  INFO_PLIST="$APP_PATH/Contents/Info.plist"
  if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: app Info.plist not found at $INFO_PLIST."
    exit 1
  fi

  APP_MARKETING_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
  APP_BUILD_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")
  if [ "$APP_MARKETING_VERSION" != "$MARKETING_VERSION" ]; then
    echo "Error: app version '$APP_MARKETING_VERSION' does not match '$MARKETING_VERSION'."
    exit 1
  fi
  if [ "$APP_BUILD_VERSION" != "$BUILD_VERSION" ]; then
    echo "Error: app build '$APP_BUILD_VERSION' does not match '$BUILD_VERSION'."
    exit 1
  fi
fi

echo "Version verified: $MARKETING_VERSION ($BUILD_VERSION)"
