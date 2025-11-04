#!/bin/bash

# Quick script to send a broadcast notification to all One Room users
# Usage: ./send_broadcast.sh "Title" "Message body"

# CONFIGURATION
# Get your Server Key from Firebase Console → Project Settings → Cloud Messaging
# Replace the value below with your actual FCM Server Key
FCM_SERVER_KEY="YOUR_FIREBASE_SERVER_KEY_HERE"

# Check if title and body are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: ./send_broadcast.sh \"Title\" \"Message body\""
    echo ""
    echo "Example:"
    echo "  ./send_broadcast.sh \"🎉 New Update!\" \"Download version 2.0 now\""
    exit 1
fi

TITLE="$1"
BODY="$2"

# Check if server key is set
if [ "$FCM_SERVER_KEY" == "YOUR_FIREBASE_SERVER_KEY_HERE" ]; then
    echo "❌ Error: FCM_SERVER_KEY not configured"
    echo ""
    echo "Please edit this script and add your Firebase Server Key:"
    echo "1. Go to Firebase Console → Project Settings"
    echo "2. Click on 'Cloud Messaging' tab"
    echo "3. Copy the 'Server key' under Cloud Messaging API (Legacy)"
    echo "4. Replace 'YOUR_FIREBASE_SERVER_KEY_HERE' in this script with your key"
    exit 1
fi

echo "📤 Sending broadcast notification..."
echo "Title: $TITLE"
echo "Body: $BODY"
echo ""

# Send the notification
RESPONSE=$(curl -s -X POST https://fcm.googleapis.com/fcm/send \
-H "Authorization: key=$FCM_SERVER_KEY" \
-H "Content-Type: application/json" \
-d "{
  \"to\": \"/topics/all_users\",
  \"notification\": {
    \"title\": \"$TITLE\",
    \"body\": \"$BODY\",
    \"sound\": \"default\",
    \"badge\": \"1\"
  },
  \"data\": {
    \"type\": \"broadcast\",
    \"timestamp\": \"$(date +%s)\"
  },
  \"priority\": \"high\"
}")

# Check response
if echo "$RESPONSE" | grep -q "message_id"; then
    echo "✅ Broadcast sent successfully!"
    echo "Response: $RESPONSE"
else
    echo "❌ Failed to send broadcast"
    echo "Response: $RESPONSE"
    echo ""
    echo "Common issues:"
    echo "- Invalid Server Key"
    echo "- FCM API (Legacy) not enabled in Firebase Console"
    echo "- Network connection issues"
fi
