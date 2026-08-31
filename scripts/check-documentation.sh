#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_FILE="$PROJECT_DIR/PtionsPlus.xcodeproj/project.pbxproj"

if grep -R --line-number -E 'PresetShortcut|MouseDetector\.swift|No tests exist' \
  "$PROJECT_DIR/README.md" "$PROJECT_DIR/AGENTS.md"; then
  echo "Error: documentation contains obsolete architecture references."
  exit 1
fi

REFERENCED_SCRIPTS=$(
  grep -hEo 'scripts/[A-Za-z0-9._+-]+\.sh' \
    "$PROJECT_DIR/README.md" "$PROJECT_DIR/AGENTS.md" \
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

# Every visible version marker on the site must agree with the build (I06).
while IFS= read -r site_version; do
  if [ "$site_version" != "$MARKETING_VERSION" ]; then
    echo "Error: website version marker '$site_version' does not match '$MARKETING_VERSION'."
    exit 1
  fi
done < <(grep -o '<span data-app-version>[^<]*</span>' "$PROJECT_DIR/docs/index.html" \
  | sed 's/.*<span data-app-version>//; s|</span>||')

# W07: the site must load nothing cross-origin. Only resource-loading
# attributes are checked; ordinary links out to GitHub are navigation.
CROSS_ORIGIN=$(
  grep -oE '<(link[^>]*rel="(stylesheet|preload|preconnect|dns-prefetch)"[^>]*|img[^>]*|script[^>]*|source[^>]*)>' \
    "$PROJECT_DIR/docs/index.html" \
  | grep -oE '(src|href)="https?://[^"]*"' || true
)
if [ -n "$CROSS_ORIGIN" ]; then
  echo "Error: the website loads third-party resources:"
  echo "$CROSS_ORIGIN"
  exit 1
fi

if grep -rlE 'url\(["'"'"']?https?://|@import\s+(url\()?["'"'"']?https?://' "$PROJECT_DIR/docs/assets" >/dev/null 2>&1; then
  echo "Error: a vendored stylesheet references a remote resource."
  exit 1
fi

# G04: tool-specific agent files point at AGENTS.md instead of restating it.
for pointer in "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.github/copilot-instructions.md"; do
  if [ ! -f "$pointer" ]; then
    echo "Error: missing agent pointer file: $pointer"
    exit 1
  fi
  if ! grep -q 'AGENTS.md' "$pointer"; then
    echo "Error: $pointer does not reference AGENTS.md."
    exit 1
  fi
  if [ "$(wc -l < "$pointer")" -gt 20 ]; then
    echo "Error: $pointer is long enough to be restating AGENTS.md rather than pointing at it."
    exit 1
  fi
done

echo "Documentation references verified."
