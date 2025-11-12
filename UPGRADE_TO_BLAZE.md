# 🚀 Upgrade to Blaze Plan - Quick Guide

## When You're Ready to Upgrade

### 1. Upgrade Your Firebase Project
- Visit: https://console.firebase.google.com/project/one-room-56ea2/usage/details
- Click "Upgrade to Blaze Plan"
- Add billing information
- Pay ₹1,000 prepayment (refundable)

### 2. Enable Firebase Storage
- Visit: https://console.firebase.google.com/project/one-room-56ea2/storage
- Click "Get Started"
- Choose "Start in production mode"
- Select location (same as Firestore)
- Click "Done"

### 3. Deploy Everything

```bash
cd "/Users/mac/Documents/Projects/One Room/one_room"

# Deploy storage rules
firebase deploy --only storage

# Deploy Cloud Functions (for automatic notifications)
firebase deploy --only functions
```

### 4. Enable Media Upload Features in Code

#### A. Chat Screen - Media Uploads
**File:** `lib/screens/chat/chat_screen.dart`

Find this section (around line 668):
```dart
// Media uploads disabled on Free plan
// Uncomment when upgraded to Blaze plan
/*
ListTile(
  leading: Icon(Icons.image_rounded, ...),
  title: const Text('Image'),
  ...
),
```

**Action:** Remove the `/*` and `*/` comment markers to enable image/video/audio uploads.

#### B. Profile Photo Upload
**File:** `lib/screens/profile/profile_screen.dart`

The profile photo upload is already in the code - it will work automatically once Storage is enabled.

#### C. Room Photo Upload
**File:** `lib/screens/home/enhanced_room_settings_screen.dart`

The room photo upload is already in the code - it will work automatically once Storage is enabled.

#### D. Expense Bill Upload
**File:** `lib/screens/expenses/modern_expense_screen.dart`

The bill image upload is already in the code - it will work automatically once Storage is enabled.

---

## Features Unlocked After Upgrade

### ✅ Media Features (requires Storage)
- 📸 Send photos in chat
- 🎥 Send videos in chat
- 🎵 Send audio in chat
- 🖼️ Upload room photos
- 📄 Upload expense receipts
- 👤 Upload profile photos

### ✅ Automatic Notifications (requires Cloud Functions)
- 🔔 Auto push notifications when:
  - Someone sends a chat message
  - Someone creates/edits an expense
  - Someone creates/edits a task
- ⏰ Daily task reminders at 8 AM UTC
- 📲 Notifications work 24/7 even when app is closed

---

## Cost Estimate

**Blaze Plan Pricing:**
- Upfront: ₹1,000 (refundable prepayment)
- Free tier includes:
  - 5 GB storage
  - 1 GB daily downloads
  - 2M Cloud Functions invocations/month
  - Most apps stay within free tier

**Typical monthly cost for your app:** ₹0 (within free tier)

Only pay if you exceed:
- 1000+ active users
- Lots of photo/video uploads
- Heavy notification traffic

---

## Current Features (Working on Free Plan)

### ✅ Already Working
- 💬 Text chat with edit/delete
- 💰 Expenses with suggested settlements
- ✅ Tasks and categories
- 📊 Balance calculations
- 🏠 Rooms and members
- 🔔 Manual broadcast notifications (via send_broadcast.sh)
- 💌 Payment reminders (shows suggested settlements)
- 🗳️ Chat polls
- 🔗 Link to expenses/tasks in chat
- 🔐 All authentication features

---

## Questions?

If you need help upgrading or enabling features, refer back to this guide or ask for assistance!

**Last Updated:** November 12, 2025
