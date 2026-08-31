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
release_date=$(date -u +%Y-%m-%d)

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

# The site is machine-owned for these three facts: the structured-data version,
# every visible version marker, and the review date the page publishes.
review_date_human=$(date -u "+%-d %B %Y")

perl -0pi -e "s/\"softwareVersion\": \"[^\"]+\"/\"softwareVersion\": \"$next_version\"/" "$WEBSITE_FILE"
perl -0pi -e "s/(<span data-app-version>)[^<]*(<\/span>)/\${1}$next_version\${2}/g" "$WEBSITE_FILE"
perl -0pi -e "s/<time datetime=\"[^\"]*\" data-reviewed>[^<]*<\/time>/<time datetime=\"$release_date\" data-reviewed>$review_date_human<\/time>/" "$WEBSITE_FILE"

# The changelog is the source of the release notes, so the entries collected
# under "## Unreleased" become the section of the version being cut.
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
echo "Site version markers and review date ($release_date) updated."
echo "Promoted the unreleased changelog entries into '## $next_version - $release_date'."
