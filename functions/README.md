# One Room – Cloud Functions

Server-side push notifications for chats, expenses, tasks, and daily reminders.

## What’s included
- Firestore triggers:
  - `rooms/{roomId}/chats/{chatId}` onCreate → send to `room_<roomId>` topic
  - `rooms/{roomId}/expenses/{expenseId}` onCreate/update/delete → to `room_<roomId>`
  - `rooms/{roomId}/tasks/{taskId}` onCreate/update/delete → to `room_<roomId>`
- Scheduled Pub/Sub job:
  - `dailyTaskReminders` runs at 08:00 UTC and sends per-user reminders for today’s `taskInstances`
- Helpers:
  - Topic sender and per-user token sender (chunks of 500)

## Prereqs
- Firebase CLI logged into the correct project (`one-room-b42b0`).
- Blaze plan (billing) required for scheduled functions.

## Install & build
```bash
cd functions
npm install
npm run build
```

## Deploy
```bash
# Ensure firebase.json contains { "functions": { "source": "functions" } }
firebase use one-room-b42b0
firebase deploy --only functions
```

## Test locally (optional)
```bash
firebase emulators:start --only functions
```

## Client notes
- Devices must subscribe to `room_<roomId>` to receive room notifications. RoomDetailScreen now subscribes automatically and unsubscribes on leave.
- Notification routing normalizes the `data.type` value (chat/chat_message, task_* → task, expense_* → expense).

## Maintenance
- Token cleanup: consider removing invalid tokens on send failures (not implemented here).
- Cron time: adjust `dailyTaskReminders` schedule/timeZone to your user base.
