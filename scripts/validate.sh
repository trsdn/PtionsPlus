#!/bin/bash
# Single validation gate. An agent or a contributor runs this before proposing
# a change, and it is the command named in AGENTS.md.
#
#   scripts/validate.sh          full run
#   scripts/validate.sh --fast   skip the UI smoke tests and the release build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

FAST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fast)
      FAST=1
      shift
      ;;
    *)
      echo "Usage: $0 [--fast]"
      exit 1
      ;;
  esac
done

FAILED=()

run_step() {
  local name="$1"
  shift
  printf '\n==> %s\n' "$name"
  if "$@"; then
    printf '    ok: %s\n' "$name"
  else
    printf '    FAILED: %s\n' "$name"
    FAILED+=("$name")
  fi
}

xcb() {
  xcodebuild \
    -project PtionsPlus.xcodeproj \
    -scheme "Ptions+" \
    -destination "platform=macOS" \
    CODE_SIGNING_ALLOWED=NO \
    "$@" \
    >/dev/null
}

# UI tests need a real code signature, so they cannot reuse xcb.
ui_tests() {
  xcodebuild \
    -project PtionsPlus.xcodeproj \
    -scheme "Ptions+" \
    -configuration Debug \
    -destination "platform=macOS" \
    test -only-testing:PtionsPlusUITests \
    >/dev/null
}

run_step "Shell syntax" bash -c 'for f in scripts/*.sh; do bash -n "$f" || exit 1; done'
run_step "Documentation references" bash scripts/check-documentation.sh
run_step "Version and product identity" bash scripts/verify-version.sh
run_step "Swift formatting and lint" bash scripts/lint.sh
run_step "Debug build" xcb -configuration Debug build
run_step "Unit tests" xcb -configuration Debug test -only-testing:PtionsPlusTests
run_step "Static analysis" xcb -configuration Debug analyze

if [ "$FAST" -eq 0 ]; then
  run_step "Release build" xcb -configuration Release build
  run_step "UI smoke tests" ui_tests
fi

printf '\n'
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All validation steps passed."
  exit 0
fi

echo "Validation failed:"
for step in "${FAILED[@]}"; do
  echo "  - $step"
done
exit 1
