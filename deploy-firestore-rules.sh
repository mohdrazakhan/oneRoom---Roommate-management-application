#!/bin/bash

# Deploy Firestore Rules Script
# This script deploys the Firestore security rules to Firebase

echo "🔥 Deploying Firestore Rules..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null
then
    echo "❌ Firebase CLI is not installed!"
    echo ""
    echo "Please install it first:"
    echo "  npm install -g firebase-tools"
    echo ""
    exit 1
fi

# Navigate to project directory
cd "$(dirname "$0")"

# Check if firestore.rules exists
if [ ! -f "firestore.rules" ]; then
    echo "❌ firestore.rules file not found!"
    exit 1
fi

echo "✅ Firebase CLI found"
echo "✅ firestore.rules file found"
echo ""

# Login check
echo "Checking Firebase login status..."
firebase login:list &> /dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Not logged in to Firebase"
    echo "Please run: firebase login"
    exit 1
fi

echo "✅ Logged in to Firebase"
echo ""

# Set the project
echo "Setting Firebase project..."
firebase use one-room-b42b0

echo ""
echo "📤 Deploying Firestore rules..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully deployed Firestore rules!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your Flutter app"
    echo "2. Try creating a room"
    echo "3. You should no longer see permission errors!"
    echo ""
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Please check the error messages above."
    echo ""
fi
