#!/bin/bash

# One Room - Send Broadcast Notification Script
# Usage: ./send_notification.sh "Title" "Message body"

TITLE="${1:-Test Notification}"
BODY="${2:-This is a test message}"
SECRET="oneroom-broadcast-2024"
URL="https://us-central1-one-room-56ea2.cloudfunctions.net/sendBroadcastHttp"

echo "📤 Sending notification..."
echo "   Title: $TITLE"
echo "   Body: $BODY"
echo ""

curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"$TITLE\", \"body\": \"$BODY\", \"secret\": \"$SECRET\"}"

echo ""
echo "✅ Done!"
