#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/PtionsPlus.xcodeproj/project.pbxproj"
WEBSITE_FILE="$PROJECT_DIR/docs/index.html"
CHANGELOG_FILE="$PROJECT_DIR/CHANGELOG.md"

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
release_date="$(date +%F)"

unreleased_entries="$("$SCRIPT_DIR/changelog.sh" section unreleased)"
if [ -z "$unreleased_entries" ]; then
  echo "Error: CHANGELOG.md has no entries under '## Unreleased'."
  echo "Describe the changes of $next_version there before bumping the version."
  exit 1
fi

if [ -n "$("$SCRIPT_DIR/changelog.sh" section "$next_version")" ]; then
  echo "Error: CHANGELOG.md already has a section for $next_version."
  exit 1
fi

perl -0pi -e "s/MARKETING_VERSION = \Q$current_version\E;/MARKETING_VERSION = $next_version;/g; s/CURRENT_PROJECT_VERSION = \Q$current_build\E;/CURRENT_PROJECT_VERSION = $next_build;/g" "$PROJECT_FILE"
perl -0pi -e "s/\"softwareVersion\": \"[^\"]+\"/\"softwareVersion\": \"$next_version\"/" "$WEBSITE_FILE"

changelog_tmp="$(mktemp)"
awk -v heading="## $next_version - $release_date" '
  { print }
  !inserted && $0 == "## Unreleased" {
    print ""
    print heading
    inserted = 1
  }
  END { if (!inserted) exit 1 }
' "$CHANGELOG_FILE" > "$changelog_tmp"
cat "$changelog_tmp" > "$CHANGELOG_FILE"
rm -f "$changelog_tmp"

echo "Updated version: $current_version ($current_build) -> $next_version ($next_build)"
echo "Promoted the unreleased changelog entries into '## $next_version - $release_date'."
