#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/PtionsPlus.xcodeproj/project.pbxproj"
SOURCE_PLIST="$PROJECT_DIR/PtionsPlus/Info.plist"
APP_PATH=""
TAG="${RELEASE_TAG:-}"

# Identity values the built artifact must carry, read from the source plist so
# this script checks that the build embedded them rather than restating them.
REPOSITORY_URL=$(/usr/libexec/PlistBuddy -c 'Print :TRSRepositoryURL' "$SOURCE_PLIST" 2>/dev/null || echo "")
ISSUES_URL=$(/usr/libexec/PlistBuddy -c 'Print :TRSIssuesURL' "$SOURCE_PLIST" 2>/dev/null || echo "")
LICENSE_IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :TRSLicenseIdentifier' "$SOURCE_PLIST" 2>/dev/null || echo "")

for pair in "TRSRepositoryURL:$REPOSITORY_URL" "TRSIssuesURL:$ISSUES_URL" "TRSLicenseIdentifier:$LICENSE_IDENTIFIER"; do
  if [ -z "${pair#*:}" ]; then
    echo "Error: ${pair%%:*} is missing from $SOURCE_PLIST."
    exit 1
  fi
done

if ! grep -q 'INFOPLIST_KEY_NSHumanReadableCopyright = "[^"]\{1,\}"' "$PROJECT_FILE"; then
  echo "Error: NSHumanReadableCopyright is not set in the build settings."
  exit 1
fi

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

  # Product identity (I02, I03, I06): the built artifact must carry its
  # repository, issue tracker, licence, and copyright. These are embedded by
  # the build, so a drift here means the plist was edited without the source.
  check_plist_key() {
    key="$1"
    expected="$2"
    if ! actual=$(/usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null); then
      echo "Error: app is missing required identity key '$key'."
      exit 1
    fi
    if [ -z "$actual" ]; then
      echo "Error: identity key '$key' is empty."
      exit 1
    fi
    if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
      echo "Error: identity key '$key' is '$actual', expected '$expected'."
      exit 1
    fi
  }

  check_plist_key TRSRepositoryURL "$REPOSITORY_URL"
  check_plist_key TRSIssuesURL "$ISSUES_URL"
  check_plist_key TRSLicenseIdentifier "$LICENSE_IDENTIFIER"
  check_plist_key NSHumanReadableCopyright ""

  if [ ! -f "$APP_PATH/Contents/Resources/LICENSE" ]; then
    echo "Error: app does not bundle its licence text."
    exit 1
  fi

  echo "Product identity verified."
fi

# I06: in CI the repository is an authoritative fact, not a constant this
# repository gets to assert. Check the embedded URLs against it so a fork, a
# rename, or a stale copied plist fails the release rather than shipping a link
# that points somewhere else.
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
  EXPECTED_REPOSITORY_URL="${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY"
  if [ "$REPOSITORY_URL" != "$EXPECTED_REPOSITORY_URL" ]; then
    echo "Error: TRSRepositoryURL is '$REPOSITORY_URL' but the repository is '$EXPECTED_REPOSITORY_URL'."
    exit 1
  fi
  if [ "$ISSUES_URL" != "$EXPECTED_REPOSITORY_URL/issues" ]; then
    echo "Error: TRSIssuesURL is '$ISSUES_URL' but the repository is '$EXPECTED_REPOSITORY_URL'."
    exit 1
  fi
  echo "Repository identity matches $GITHUB_REPOSITORY."
fi

echo "Version verified: $MARKETING_VERSION ($BUILD_VERSION)"
