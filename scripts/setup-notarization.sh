#!/bin/bash
set -euo pipefail
set +x
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RELEASE_ENV_FILE="$PROJECT_DIR/.release.env"

REPOSITORY="${PTIONSPLUS_REPOSITORY:-trsdn/PtionsPlus}"
TEAM_ID="${APPLE_TEAM_ID:-G69Z5BNY97}"
PROFILE="${NOTARY_PROFILE:-PtionsPlus}"
P12_PATH=""
GUI_MODE=false

APPLE_ID_VALUE=""
APPLE_APP_PASSWORD_VALUE=""
P12_PASSWORD=""

cleanup() {
  APPLE_ID_VALUE=""
  APPLE_APP_PASSWORD_VALUE=""
  P12_PASSWORD=""
  unset APPLE_ID_VALUE APPLE_APP_PASSWORD_VALUE P12_PASSWORD NOTARY_PASSWORD
}
trap cleanup EXIT HUP INT TERM

usage() {
  cat <<'EOF'
Usage: scripts/setup-notarization.sh [options]

Configure PtionsPlus GitHub Actions release secrets and a local notarytool profile.

Options:
  --repo OWNER/REPO   GitHub repository (default: trsdn/PtionsPlus)
  --team-id ID        Apple Developer team ID
  --profile NAME      Local notarytool profile (default: PtionsPlus)
  --p12 PATH          Developer ID Application certificate export
  --gui               Read files and credentials from secure macOS dialogs
  -h, --help          Show this help
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPOSITORY="${2:-}"
      shift 2
      ;;
    --team-id)
      TEAM_ID="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --p12)
      P12_PATH="${2:-}"
      shift 2
      ;;
    --gui)
      GUI_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
  || die "Repository must use OWNER/REPO format."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] \
  || die "Team ID must contain 10 uppercase letters or digits."
[[ "$PROFILE" =~ ^[A-Za-z0-9._-]+$ ]] \
  || die "Profile contains unsupported characters."

for tool in gh xcrun security openssl base64 expect; do
  command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool"
done
gh auth status >/dev/null 2>&1 || die "GitHub CLI authentication is required."
xcrun --find notarytool >/dev/null 2>&1 || die "notarytool is unavailable."

if [ -L "$RELEASE_ENV_FILE" ]; then
  die ".release.env must not be a symbolic link."
fi
git -C "$PROJECT_DIR" check-ignore -q -- .release.env \
  || die ".release.env must remain ignored by git."

SECRET_NAMES=$(
  gh secret list --repo "$REPOSITORY" --app actions --json name --jq '.[].name'
)

secret_exists() {
  grep -Fqx "$1" <<< "$SECRET_NAMES"
}

gui_value() {
  local prompt="$1"
  local hidden="${2:-false}"
  local default_value="${3:-}"
  local hidden_clause=""
  if [ "$hidden" = true ]; then
    hidden_clause="with hidden answer"
  fi

  osascript 2>/dev/null <<APPLESCRIPT
try
  set response to display dialog "$prompt" default answer "$default_value" with title "PtionsPlus Release Setup" buttons {"Cancel", "Continue"} default button "Continue" cancel button "Cancel" $hidden_clause
  return text returned of response
on error number -128
  return "__CANCEL__"
end try
APPLESCRIPT
}

if [ "$GUI_MODE" = true ]; then
  command -v osascript >/dev/null 2>&1 || die "--gui requires macOS osascript."
  launchctl print "gui/$(id -u)" >/dev/null 2>&1 \
    || die "--gui requires an active macOS login session."
elif [ ! -t 0 ] || [ ! -t 2 ]; then
  die "Run this script from an interactive terminal or use --gui."
fi

if ! secret_exists MACOS_CERTIFICATE || ! secret_exists MACOS_CERTIFICATE_PWD; then
  if [ -z "$P12_PATH" ]; then
    if [ "$GUI_MODE" = true ]; then
      P12_PATH=$(
        osascript 2>/dev/null <<'APPLESCRIPT'
try
  return POSIX path of (choose file with prompt "Select the Developer ID Application .p12 export")
on error number -128
  return "__CANCEL__"
end try
APPLESCRIPT
      )
      [ "$P12_PATH" != "__CANCEL__" ] || die "Certificate selection canceled."
    else
      printf 'Developer ID .p12 path: ' >&2
      IFS= read -r P12_PATH
    fi
  fi
  [ -f "$P12_PATH" ] || die "P12 file not found: $P12_PATH"
  case "${P12_PATH##*.}" in
    p12|P12|pfx|PFX) ;;
    *) die "Select a .p12 or .pfx export that includes the private key; a .cer file is insufficient." ;;
  esac

  if [ "$GUI_MODE" = true ]; then
    P12_PASSWORD=$(gui_value "P12 export password:" true)
    [ "$P12_PASSWORD" != "__CANCEL__" ] || die "Credential setup canceled."
  else
    printf 'P12 export password: ' >&2
    IFS= read -r -s P12_PASSWORD
    printf '\n' >&2
  fi
  [ -n "$P12_PASSWORD" ] || die "P12 password cannot be empty."

  if ! printf '%s\n' "$P12_PASSWORD" \
    | openssl pkcs12 -in "$P12_PATH" -passin stdin -noout >/dev/null 2>&1; then
    if ! printf '%s\n' "$P12_PASSWORD" \
      | openssl pkcs12 -legacy -in "$P12_PATH" -passin stdin -noout >/dev/null 2>&1; then
      die "The P12/PFX file or export password is invalid."
    fi
  fi

  base64 < "$P12_PATH" \
    | gh secret set MACOS_CERTIFICATE --repo "$REPOSITORY" --app actions >/dev/null
  printf '%s' "$P12_PASSWORD" \
    | gh secret set MACOS_CERTIFICATE_PWD --repo "$REPOSITORY" --app actions >/dev/null
fi

DEFAULT_APPLE_ID=$(git -C "$PROJECT_DIR" config user.email || true)
if [ "$GUI_MODE" = true ]; then
  APPLE_ID_VALUE=$(gui_value "Apple ID:" false "$DEFAULT_APPLE_ID")
  [ "$APPLE_ID_VALUE" != "__CANCEL__" ] || die "Credential setup canceled."
  APPLE_APP_PASSWORD_VALUE=$(gui_value "Apple app-specific password:" true)
  [ "$APPLE_APP_PASSWORD_VALUE" != "__CANCEL__" ] || die "Credential setup canceled."
else
  printf 'Apple ID [%s]: ' "$DEFAULT_APPLE_ID" >&2
  IFS= read -r APPLE_ID_VALUE
  APPLE_ID_VALUE="${APPLE_ID_VALUE:-$DEFAULT_APPLE_ID}"
  printf 'Apple app-specific password: ' >&2
  IFS= read -r -s APPLE_APP_PASSWORD_VALUE
  printf '\n' >&2
fi

[ -n "$APPLE_ID_VALUE" ] || die "Apple ID cannot be empty."
[ -n "$APPLE_APP_PASSWORD_VALUE" ] || die "App-specific password cannot be empty."

printf '%s' "$APPLE_ID_VALUE" \
  | gh secret set APPLE_ID --repo "$REPOSITORY" --app actions >/dev/null
printf '%s' "$TEAM_ID" \
  | gh secret set APPLE_TEAM_ID --repo "$REPOSITORY" --app actions >/dev/null
printf '%s' "$APPLE_APP_PASSWORD_VALUE" \
  | gh secret set APPLE_APP_PASSWORD --repo "$REPOSITORY" --app actions >/dev/null

export NOTARY_PASSWORD="$APPLE_APP_PASSWORD_VALUE"
if ! expect -f - "$PROFILE" "$APPLE_ID_VALUE" "$TEAM_ID" <<'EXPECT'
set timeout 120
log_user 0
set profile [lindex $argv 0]
set apple_id [lindex $argv 1]
set team_id [lindex $argv 2]
spawn xcrun notarytool store-credentials $profile --apple-id $apple_id --team-id $team_id
expect {
  -re {(?i)password.*:} {
    send -- "$env(NOTARY_PASSWORD)\r"
    exp_continue
  }
  eof {
    catch wait result
    exit [lindex $result 3]
  }
  timeout {
    exit 124
  }
}
EXPECT
then
  die "notarytool rejected or could not store the credentials."
fi
unset NOTARY_PASSWORD

IDENTITY=$(
  security find-identity -v -p codesigning \
    | awk -F'"' '/Developer ID Application/ && !identity { identity = $2 } END { print identity }'
)
[ -n "$IDENTITY" ] || die "No Developer ID Application identity is installed locally."

{
  printf 'TEAM_ID=%q\n' "$TEAM_ID"
  printf 'CODE_SIGN_IDENTITY=%q\n' "$IDENTITY"
  printf 'NOTARY_PROFILE=%q\n' "$PROFILE"
} > "$RELEASE_ENV_FILE"

"$SCRIPT_DIR/verify-version.sh"
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null

printf 'Configured GitHub Actions secrets for %s:\n' "$REPOSITORY"
gh secret list --repo "$REPOSITORY" --app actions \
  | awk '{print "  " $1}'
printf 'Configured local notarytool profile: %s\n' "$PROFILE"
