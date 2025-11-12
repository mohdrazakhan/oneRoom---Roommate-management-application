#!/bin/bash
# Secure & flexible FCM broadcast sender
#
# Usage (Legacy HTTP):
#   FCM_SERVER_KEY=AAA... ./send_broadcast.sh "Title" "Body"
#   ./send_broadcast.sh "Title" "Body" all_users
#
# Usage (HTTP v1):
#   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
#   ./send_broadcast.sh --v1 "Title" "Body" all_users
#
# Arguments:
#   [--v1]            Use FCM HTTP v1 API (recommended). If omitted, uses legacy key.
#   "Title"           Notification title
#   "Body"            Notification body
#   [topic]           Topic name WITHOUT /topics/ prefix (default: all_users)
#
# Requirements:
#   - curl
#   - jq (optional; for pretty output)
#   - gcloud (ONLY if using --v1 and you rely on ADC instead of manual token code)
#
# Safety: set -e to stop on error, -u undefined vars error, -o pipefail for pipelines.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env if present (does not override existing exported vars)
if [ -f "$SCRIPT_DIR/.env" ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$SCRIPT_DIR/.env" | grep '=' | cut -d= -f1) >/dev/null 2>&1 || true
  # shellcheck disable=SC1090
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'

function usage() {
  cat <<USAGE
${COLOR_BLUE}FCM Broadcast Sender${COLOR_RESET}
Usage: $0 [--v1] "Title" "Body" [topic]

Examples:
  FCM_SERVER_KEY=AAAA... $0 "Hello" "This is a test"
  $0 "Update" "Version 2.0 live" all_users
  GOOGLE_APPLICATION_CREDENTIALS=svc.json $0 --v1 "Hi" "Using HTTP v1" marketing

Environment variables:
  FCM_SERVER_KEY   Legacy server key (if not using --v1)
  GOOGLE_APPLICATION_CREDENTIALS  Path to service account (for --v1 if not logged in with gcloud)
USAGE
}

USE_V1=false
POSITIONALS=()
for arg in "$@"; do
  case "$arg" in
    --v1)
      USE_V1=true
      shift
      ;;
    -h|--help)
      usage; exit 0;;
    *)
      POSITIONALS+=("$arg")
      shift
      ;;
  esac
done

set +u # allow unset while parsing positionals
TITLE="${POSITIONALS[0]:-}"
BODY="${POSITIONALS[1]:-}"
TOPIC="${POSITIONALS[2]:-all_users}"
set -u

if [ -z "$TITLE" ] || [ -z "$BODY" ]; then
  usage; echo "${COLOR_RED}Error:${COLOR_RESET} Title and Body required" >&2; exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo -e "${COLOR_RED}Error:${COLOR_RESET} curl is required" >&2; exit 1
fi

echo -e "${COLOR_BLUE}▶ Sending notification${COLOR_RESET}"
echo -e "Topic: ${COLOR_YELLOW}$TOPIC${COLOR_RESET}"
echo -e "Title: $TITLE"
echo -e "Body : $BODY"
echo "Mode : $([ "$USE_V1" = true ] && echo 'HTTP v1' || echo 'Legacy HTTP')"
echo ""

NOW_TS="$(date +%s)"

if [ "$USE_V1" = false ]; then
  # ----- Legacy HTTP API -----
  FCM_SERVER_KEY="${FCM_SERVER_KEY:-}" || true
  if [ -z "${FCM_SERVER_KEY:-}" ]; then
    echo -e "${COLOR_RED}Error:${COLOR_RESET} FCM_SERVER_KEY not set. Export it or put it in .env" >&2
    exit 1
  fi
  RESPONSE=$(curl -s -X POST https://fcm.googleapis.com/fcm/send \
    -H "Authorization: key=$FCM_SERVER_KEY" \
    -H "Content-Type: application/json" \
    -d "$(cat <<JSON
{
  \"to\": \"/topics/$TOPIC\",
  \"notification\": {
    \"title\": \"$TITLE\",
    \"body\": \"$BODY\",
    \"sound\": \"default\",
    \"badge\": \"1\"
  },
  \"data\": {
    \"type\": \"broadcast\",
    \"topic\": \"$TOPIC\",
    \"timestamp\": \"$NOW_TS\"
  },
  \"priority\": \"high\"
}
JSON
  )")
else
  # ----- HTTP v1 API -----
  # Acquire OAuth2 access token for scope https://www.googleapis.com/auth/firebase.messaging
  get_access_token() {
    # Prefer gcloud if available and either ADC or GOOGLE_APPLICATION_CREDENTIALS is set.
    if command -v gcloud >/dev/null 2>&1; then
      if ACCESS_TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null); then
        echo "$ACCESS_TOKEN"; return 0
      fi
    fi
    # Fallback 1: python inline (requires google-auth library). We attempt only if service account file present.
    if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
      python3 - <<'PY' || true
import json, time, sys, os
from google.oauth2 import service_account
from google.auth.transport.requests import Request
path=os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
if not path: sys.exit(1)
creds=service_account.Credentials.from_service_account_file(path, scopes=['https://www.googleapis.com/auth/firebase.messaging'])
creds.refresh(Request())
print(creds.token)
PY
    else
      :
    fi
    # Fallback 2: Pure Bash + OpenSSL JWT using service account (no extra libs)
    # Requires: python3 (stdlib only) and openssl
    if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ] \
       && command -v openssl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
      PEM_FILE=$(mktemp /tmp/fcm-sa.XXXXXX.pem)
      # Extract client_email and token_uri, and write private_key to PEM_FILE
      # Use process substitution to capture two lines safely
      mapfile -t _INFO < <(python3 - "$GOOGLE_APPLICATION_CREDENTIALS" "$PEM_FILE" <<'PY2'
import sys, json, pathlib
path = sys.argv[1]
pem_path = sys.argv[2]
with open(path) as f:
    data = json.load(f)
client_email = data["client_email"]
token_uri = data.get("token_uri", "https://oauth2.googleapis.com/token")
priv = data["private_key"]
pathlib.Path(pem_path).write_text(priv)
print(client_email)
print(token_uri)
PY2
)
      CLIENT_EMAIL="${_INFO[0]:-}"
      TOKEN_URI="${_INFO[1]:-}"
      if [ -z "${CLIENT_EMAIL:-}" ] || [ -z "${TOKEN_URI:-}" ]; then
        rm -f "$PEM_FILE" 2>/dev/null || true
      else
        # Build JWT header and payload
        local header payload header_b64 payload_b64 unsigned sig jwt
        header='{"alg":"RS256","typ":"JWT"}'
        iat=$(date +%s)
        exp=$((iat+3600))
        scope='https://www.googleapis.com/auth/firebase.messaging'
        payload=$(cat <<JSON_PAYLOAD
{"iss":"$CLIENT_EMAIL","scope":"$scope","aud":"$TOKEN_URI","exp":$exp,"iat":$iat}
JSON_PAYLOAD
)
        # base64url encode (no padding)
        header_b64=$(printf '%s' "$header" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
        payload_b64=$(printf '%s' "$payload" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
        unsigned="$header_b64.$payload_b64"
        sig=$(printf '%s' "$unsigned" | openssl dgst -sha256 -sign "$PEM_FILE" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
        jwt="$unsigned.$sig"
        rm -f "$PEM_FILE" 2>/dev/null || true
        # Exchange for access token
        ACCESS_TOKEN=$(curl -s -X POST "$TOKEN_URI" \
          -H 'Content-Type: application/x-www-form-urlencoded' \
          --data "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=$jwt" | \
          python3 - <<'PY3'
import sys, json
data=json.loads(sys.stdin.read() or '{}')
print(data.get('access_token',''))
PY3
)
        if [ -n "$ACCESS_TOKEN" ]; then
          echo "$ACCESS_TOKEN"; return 0
        fi
      fi
    fi
    return 1
  }

  ACCESS_TOKEN=$(get_access_token || true)
  if [ -z "${ACCESS_TOKEN:-}" ]; then
    echo -e "${COLOR_RED}Error:${COLOR_RESET} Could not obtain OAuth access token. Install gcloud (preferred) OR set GOOGLE_APPLICATION_CREDENTIALS and pip install google-auth." >&2
    exit 1
  fi

  # Need project id (extract from service account if possible)
  PROJECT_ID="${FIREBASE_PROJECT_ID:-}" || true
  if [ -z "$PROJECT_ID" ] && [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    PROJECT_ID=$(grep -o '"project_id": *"[^"]*"' "$GOOGLE_APPLICATION_CREDENTIALS" | head -1 | cut -d '"' -f4)
  fi
  if [ -z "$PROJECT_ID" ]; then
    echo -e "${COLOR_RED}Error:${COLOR_RESET} FIREBASE_PROJECT_ID not set and could not infer from credentials" >&2
    exit 1
  fi

  # Build JSON payload without extra escaping
  read -r -d '' V1_PAYLOAD <<EOF || true
{
  "message": {
    "topic": "$TOPIC",
    "notification": {
      "title": "$TITLE",
      "body": "$BODY"
    },
    "data": {
      "type": "broadcast",
      "topic": "$TOPIC",
      "timestamp": "$NOW_TS"
    }
  }
}
EOF
  RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json; charset=UTF-8" \
    "https://fcm.googleapis.com/v1/projects/$PROJECT_ID/messages:send" \
    --data-raw "$V1_PAYLOAD")
fi

# ---------- Result handling ----------
SUCCESS=false
if [ "$USE_V1" = false ]; then
  if echo "$RESPONSE" | grep -q '"message_id"'; then SUCCESS=true; fi
else
  if echo "$RESPONSE" | grep -q '"name"'; then SUCCESS=true; fi
fi

if $SUCCESS; then
  echo -e "${COLOR_GREEN}✔ Success${COLOR_RESET}"
else
  echo -e "${COLOR_RED}✖ Failed${COLOR_RESET}"
fi

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq . || true
else
  echo "$RESPONSE"
fi

if ! $SUCCESS; then
  echo ""
  echo "Troubleshooting:" >&2
  if [ "$USE_V1" = false ]; then
    echo " - Verify legacy server key (Project Settings > Cloud Messaging > Legacy)" >&2
    echo " - Legacy API may be disabled; consider --v1" >&2
  else
    echo " - Ensure service account has firebase.messaging.send permission" >&2
    echo " - Check project id: $PROJECT_ID" >&2
    echo " - If using gcloud, run: gcloud auth application-default login" >&2
  fi
  echo " - Ensure device subscribed to topic: all_users" >&2
  echo " - Check device logs for reception" >&2
  exit 1
fi

exit 0
