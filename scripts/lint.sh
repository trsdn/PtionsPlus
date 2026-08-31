#!/bin/bash
# Formatting and lint gate for Swift sources.
#
# Uses swift-format, which ships with Xcode 16 and later as `xcrun swift-format`.
# When it is unavailable the script reports that and exits 0, so a contributor
# on an older toolchain is not blocked; CI pins a runner where it exists and
# therefore always enforces it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODE="lint"

while [ $# -gt 0 ]; do
  case "$1" in
    --fix)
      MODE="fix"
      shift
      ;;
    *)
      echo "Usage: $0 [--fix]"
      exit 1
      ;;
  esac
done

if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "swift-format not found in the active toolchain; skipping."
  echo "Install Xcode 16 or later to run this check locally."
  exit 0
fi

cd "$PROJECT_DIR"

TARGETS=(PtionsPlus PtionsPlusTests PtionsPlusUITests)

if [ "$MODE" = "fix" ]; then
  xcrun swift-format format --in-place --recursive --configuration .swift-format "${TARGETS[@]}"
  echo "Formatting applied."
else
  xcrun swift-format lint --strict --recursive --configuration .swift-format "${TARGETS[@]}"
  echo "Formatting and lint checks passed."
fi
