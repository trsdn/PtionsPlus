#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/PtionsPlus.xcodeproj/project.pbxproj"

if [ $# -ne 1 ]; then
  echo "Usage: $0 patch|minor|major"
  exit 1
fi

KIND="$1"

current_version=$(grep -m1 'MARKETING_VERSION = ' "$PROJECT_FILE" | sed 's/.*= //; s/;//')
current_build=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT_FILE" | sed 's/.*= //; s/;//')

IFS='.' read -r major minor patch <<< "$current_version"

case "$KIND" in
  patch)
    patch=$((patch + 1))
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  *)
    echo "Usage: $0 patch|minor|major"
    exit 1
    ;;
esac

next_version="$major.$minor.$patch"
next_build=$((current_build + 1))

perl -0pi -e "s/MARKETING_VERSION = \Q$current_version\E;/MARKETING_VERSION = $next_version;/g; s/CURRENT_PROJECT_VERSION = \Q$current_build\E;/CURRENT_PROJECT_VERSION = $next_build;/g" "$PROJECT_FILE"

echo "Updated version: $current_version ($current_build) -> $next_version ($next_build)"