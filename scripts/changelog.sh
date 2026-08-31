#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHANGELOG_FILE="$PROJECT_DIR/CHANGELOG.md"
UNRELEASED_HEADING="## Unreleased"

usage() {
  cat <<'USAGE'
Usage:
  scripts/changelog.sh section <version|unreleased>
  scripts/changelog.sh release-notes <version|vX.Y.Z> [--output FILE]

section        Print the entries of one changelog section without its heading.
release-notes  Verify the changelog is release ready for one version and print
               its entries, optionally writing them to FILE.

The release-notes check fails when the version has no dated section, when that
section has no entries, or when entries are still parked under "## Unreleased"
and would therefore never reach any release notes. A tag that predates the
"## Unreleased" convention has no parked entries and passes.
USAGE
}

normalize_version() {
  local value="${1#v}"
  if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: invalid version '$1'; expected X.Y.Z or vX.Y.Z." >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

heading_line() {
  awk -v prefix="$1" 'index($0, prefix) == 1 { print; exit }' "$CHANGELOG_FILE"
}

section_body() {
  awk -v prefix="$1" '
    started && index($0, "## ") == 1 { exit }
    started { print }
    !started && index($0, prefix) == 1 { started = 1 }
  ' "$CHANGELOG_FILE" | awk '
    NF { if (!first) first = NR; last = NR }
    { lines[NR] = $0 }
    END {
      if (!first) exit
      for (i = first; i <= last; i++) print lines[i]
    }
  '
}

require_changelog() {
  if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Error: $CHANGELOG_FILE not found." >&2
    exit 1
  fi
}

require_unreleased_heading() {
  if [ -z "$(heading_line "$UNRELEASED_HEADING")" ]; then
    echo "Error: CHANGELOG.md must keep an '$UNRELEASED_HEADING' section." >&2
    exit 1
  fi
}

cmd_section() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    usage >&2
    exit 1
  fi

  case "$target" in
    unreleased | Unreleased)
      require_unreleased_heading
      section_body "$UNRELEASED_HEADING"
      ;;
    *)
      local version
      version="$(normalize_version "$target")"
      section_body "## $version - "
      ;;
  esac
}

cmd_release_notes() {
  local target="" output=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --output)
        output="${2:-}"
        shift 2
        ;;
      -*)
        usage >&2
        exit 1
        ;;
      *)
        if [ -n "$target" ]; then
          usage >&2
          exit 1
        fi
        target="$1"
        shift
        ;;
    esac
  done

  if [ -z "$target" ]; then
    usage >&2
    exit 1
  fi

  local version
  version="$(normalize_version "$target")"

  local unreleased
  unreleased="$(section_body "$UNRELEASED_HEADING")"
  if [ -n "$unreleased" ]; then
    echo "Error: unreleased entries would bypass release $version:" >&2
    printf '%s\n' "$unreleased" >&2
    echo "Promote them into a released section with scripts/bump-version.sh." >&2
    exit 1
  fi

  local heading
  heading="$(heading_line "## $version - ")"
  if [ -z "$heading" ]; then
    echo "Error: CHANGELOG.md has no '## $version - YYYY-MM-DD' section." >&2
    exit 1
  fi

  if [[ ! "$heading" =~ ^##\ "$version"\ -\ [0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: changelog heading '$heading' must read '## $version - YYYY-MM-DD'." >&2
    exit 1
  fi

  local notes
  notes="$(section_body "## $version - ")"
  if [ -z "$notes" ]; then
    echo "Error: changelog section for $version has no entries." >&2
    exit 1
  fi

  if [ -n "$output" ]; then
    mkdir -p "$(dirname "$output")"
    printf '%s\n' "$notes" > "$output"
    echo "Release notes for $version written to $output"
  else
    printf '%s\n' "$notes"
  fi
}

require_changelog

COMMAND="${1:-}"
[ $# -gt 0 ] && shift

case "$COMMAND" in
  section)
    cmd_section "$@"
    ;;
  release-notes)
    cmd_release_notes "$@"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
