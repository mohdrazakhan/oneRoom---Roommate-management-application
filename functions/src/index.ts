import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Helper: build topic name for a room
const roomTopic = (roomId: string) => `room_${roomId}`;

// Helper: send to room topic with common data routing
async function sendToRoom(roomId: string, title: string, body: string, data: Record<string, string>) {
  const topic = roomTopic(roomId);
  const message: admin.messaging.Message = {
    topic,
    notification: { title, body },
    data: {
      roomId,
      ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    },
    android: { priority: 'high', notification: { channelId: 'one_room_channel' } },
    apns: { payload: { aps: { sound: 'default' } } },
  };
  await messaging.send(message);
}

// Helper: fetch FCM tokens for a user
async function getUserTokens(uid: string): Promise<string[]> {
  const snap = await db.collection('users').doc(uid).collection('tokens').get();
  return snap.docs.map((d: admin.firestore.QueryDocumentSnapshot) => (d.data().token as string)).filter(Boolean);
}

// Helper: send to a set of tokens in chunks
async function sendToTokens(tokens: string[], title: string, body: string, data: Record<string, string>) {
  const chunks: string[][] = [];
  const size = 500;
  for (let i = 0; i < tokens.length; i += size) chunks.push(tokens.slice(i, i + size));

  for (const chunk of chunks) {
    if (!chunk.length) continue;
    const message: admin.messaging.MulticastMessage = {
      tokens: chunk,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high', notification: { channelId: 'one_room_channel' } },
      apns: { payload: { aps: { sound: 'default' } } },
    };
    await messaging.sendEachForMulticast(message);
  }
}

// CHAT: on new message -> send to room topic
export const onChatCreated = functions.firestore
  .document('rooms/{roomId}/chats/{chatId}')
  .onCreate(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any>;
    const type = (data.type as string) || 'text';

    // Resolve room name for better UX
    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    // Compose body preview
    let body = '';
    if (type === 'text' && data.text) body = String(data.text).slice(0, 120);
    else if (type === 'image') body = 'Sent a photo';
    else if (type === 'video') body = 'Sent a video';
    else if (type === 'audio') body = 'Sent an audio message';
    else if (type === 'poll') body = `Started a poll: ${data.pollQuestion ?? ''}`.trim();
    else if (type === 'reminder') body = 'Sent a payment reminder';
    else if (type === 'link') body = `Shared a link to ${data.linkType ?? 'an item'}`;
    else body = 'New message';

    await sendToRoom(roomId, `💬 New message in ${roomName}`, body, {
      type: 'chat',
      roomId,
      roomName,
      screen: 'chat',
    });
  });

// EXPENSES: on create/update/delete -> send to room topic
export const onExpenseCreated = functions.firestore
  .document('rooms/{roomId}/expenses/{expenseId}')
  .onCreate(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any>;
    const description = (data.description as string) || 'an expense';
    const amount = data.amount != null ? Number(data.amount) : undefined;
    const currency = '₹';

    // Resolve room name
    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    const body = amount != null ? `Added "${description}" - ${currency}${amount.toFixed(2)}` : `Added "${description}"`;
    await sendToRoom(roomId, `💰 New expense in ${roomName}`, body, {
      type: 'expense',
      roomId,
      roomName,
      screen: 'expenses',
      action: 'created',
    });
  });

export const onExpenseUpdated = functions.firestore
  .document('rooms/{roomId}/expenses/{expenseId}')
  .onUpdate(async (
    change: functions.Change<admin.firestore.DocumentSnapshot>,
    ctx: functions.EventContext,
  ) => {
    const roomId = ctx.params.roomId as string;
    const after = change.after.data() as Record<string, any>;
    const description = (after.description as string) || 'an expense';

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoom(roomId, `✏️ Expense updated in ${roomName}`, `Updated "${description}"`, {
      type: 'expense',
      roomId,
      roomName,
      screen: 'expenses',
      action: 'updated',
    });
  });

export const onExpenseDeleted = functions.firestore
  .document('rooms/{roomId}/expenses/{expenseId}')
  .onDelete(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any> | undefined;
    const description = (data?.description as string) || 'an expense';

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoom(roomId, `🗑️ Expense deleted in ${roomName}`, `Deleted "${description}"`, {
      type: 'expense',
      roomId,
      roomName,
      screen: 'expenses',
      action: 'deleted',
    });
  });

// TASKS: on create/update/delete -> send to room topic
export const onTaskCreated = functions.firestore
  .document('rooms/{roomId}/tasks/{taskId}')
  .onCreate(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any>;
    const title = (data.title as string) || (data.name as string) || 'Task';

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoom(roomId, `✅ New task in ${roomName}`, `Created "${title}"`, {
      type: 'task',
      roomId,
      roomName,
      screen: 'tasks',
      action: 'created',
    });
  });

export const onTaskUpdated = functions.firestore
  .document('rooms/{roomId}/tasks/{taskId}')
  .onUpdate(async (
    change: functions.Change<admin.firestore.DocumentSnapshot>,
    ctx: functions.EventContext,
  ) => {
    const roomId = ctx.params.roomId as string;
    const after = change.after.data() as Record<string, any>;
    const title = (after.title as string) || (after.name as string) || 'Task';

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoom(roomId, `✏️ Task updated in ${roomName}`, `Updated "${title}"`, {
      type: 'task',
      roomId,
      roomName,
      screen: 'tasks',
      action: 'updated',
    });
  });

export const onTaskDeleted = functions.firestore
  .document('rooms/{roomId}/tasks/{taskId}')
  .onDelete(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any> | undefined;
    const title = (data?.title as string) || (data?.name as string) || 'Task';

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoom(roomId, `🗑️ Task deleted in ${roomName}`, `Deleted "${title}"`, {
      type: 'task',
      roomId,
      roomName,
      screen: 'tasks',
      action: 'deleted',
    });
  });

// SCHEDULED: daily reminders for taskInstances due today
// Runs every day at 08:00 UTC. Adjust as needed.
export const dailyTaskReminders = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    const today = new Date();
    const start = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), 0, 0, 0));
    const end = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + 1, 0, 0, 0));

    // For each room, fetch today's taskInstances and notify assignees
    const roomsSnap = await db.collection('rooms').get();
    for (const room of roomsSnap.docs) {
      const roomId = room.id;
      const roomName = (room.data().name as string) || 'Room';
      const q = db
        .collection('rooms')
        .doc(roomId)
        .collection('taskInstances')
        .where('scheduledDate', '>=', admin.firestore.Timestamp.fromDate(start))
        .where('scheduledDate', '<', admin.firestore.Timestamp.fromDate(end));

      const snap = await q.get();
      if (snap.empty) continue;

      // Group by assignee
      const byUser = new Map<string, string[]>();
      for (const d of snap.docs) {
        const data = d.data() as any;
        const uid = data.assignedTo as string | undefined;
        const title = (data.taskTitle as string) || (data.title as string) || 'Task';
        if (!uid) continue;
        const arr = byUser.get(uid) ?? [];
        arr.push(title);
        byUser.set(uid, arr);
      }

      for (const [uid, titles] of byUser.entries()) {
        const tokens = await getUserTokens(uid);
        if (!tokens.length) continue;
        const body = titles.length === 1
          ? `Don't forget: "${titles[0]}" in ${roomName}`
          : `You have ${titles.length} tasks today in ${roomName}`;
        await sendToTokens(tokens, '⏰ Task reminder', body, {
          type: 'task',
          screen: 'my_tasks',
          roomId,
          roomName,
          action: 'reminder',
        });
      }
    }

    return null;
  });
