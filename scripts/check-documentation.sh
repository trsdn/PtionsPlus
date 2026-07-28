#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/PtionsPlus.xcodeproj/project.pbxproj"

if grep -R --line-number --fixed-strings 'scripts/deploy.sh' \
  "$PROJECT_DIR/README.md" "$PROJECT_DIR/CLAUDE.md"; then
  echo "Error: documentation references the nonexistent deploy script."
  exit 1
fi

if grep -R --line-number -E 'PresetShortcut|MouseDetector\.swift|No tests exist' \
  "$PROJECT_DIR/README.md" "$PROJECT_DIR/CLAUDE.md"; then
  echo "Error: documentation contains obsolete architecture references."
  exit 1
fi

REFERENCED_SCRIPTS=$(
  grep -hEo 'scripts/[A-Za-z0-9._+-]+\.sh' \
    "$PROJECT_DIR/README.md" "$PROJECT_DIR/CLAUDE.md" \
  | sort -u
)

while IFS= read -r script; do
  [ -z "$script" ] && continue
  if [ ! -f "$PROJECT_DIR/$script" ]; then
    echo "Error: documented script is missing: $script"
    exit 1
  fi
done <<< "$REFERENCED_SCRIPTS"

MARKETING_VERSION=$(grep -m1 'MARKETING_VERSION = ' "$PROJECT_FILE" | sed 's/.*= //; s/;//')
WEBSITE_VERSION=$(grep -m1 '"softwareVersion":' "$PROJECT_DIR/docs/index.html" | sed 's/.*: "//; s/".*//')
if [ "$WEBSITE_VERSION" != "$MARKETING_VERSION" ]; then
  echo "Error: website version '$WEBSITE_VERSION' does not match '$MARKETING_VERSION'."
  exit 1
fi

if ! grep -q 'MX Master 4' "$PROJECT_DIR/docs/index.html"; then
  echo "Error: website compatibility list is missing MX Master 4."
  exit 1
fi

echo "Documentation references verified."
