import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Helper: build topic name for a room
const roomTopic = (roomId: string) => `room_${roomId}`;

// Helper: send to room topic with common data routing (used for broadcasts only)
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

// Helper: send notification to all room members EXCEPT the sender
async function sendToRoomExceptSender(
  roomId: string,
  senderUid: string | null | undefined,
  title: string,
  body: string,
  data: Record<string, string>
) {
  try {
    // Get room members
    const roomDoc = await db.collection('rooms').doc(roomId).get();
    const roomData = roomDoc.data();
    if (!roomData) return;

    const members: string[] = roomData.members || [];
    
    // Filter out the sender
    const recipients = senderUid ? members.filter((uid: string) => uid !== senderUid) : members;
    
    if (recipients.length === 0) return;

    // Determine notification type from data
    const notificationType = data.type || '';
    
    // Collect tokens for recipients who have the relevant notification setting enabled
    const allTokens: string[] = [];
    for (const uid of recipients) {
      // Check user's notification preferences
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.data();
      
      if (!userData) continue;
      
      // Check master notification toggle first
      const notificationsEnabled = userData.notificationsEnabled ?? true;
      if (!notificationsEnabled) continue;
      
      // Check specific notification preferences based on type
      let shouldSendToUser = true;
      
      if (notificationType === 'chat' || notificationType === 'chat_message') {
        // Check chat notifications setting
        shouldSendToUser = userData.chatNotificationsEnabled ?? true;
      } else if (notificationType === 'expense' || 
                 notificationType.startsWith('expense_')) {
        // Check expense/payment alerts setting
        shouldSendToUser = userData.expensePaymentAlertsEnabled ?? true;
      } else if (notificationType === 'task' || 
                 notificationType.startsWith('task_')) {
        // Check task reminders setting
        shouldSendToUser = userData.taskRemindersEnabled ?? true;
      }
      
      if (!shouldSendToUser) continue;
      
      // If user wants this type of notification, get their tokens
      const tokens = await getUserTokens(uid);
      allTokens.push(...tokens);
    }

    if (allTokens.length === 0) return;

    // Send to collected tokens
    await sendToTokens(allTokens, title, body, data);
  } catch (error) {
    console.error('Error sending to room except sender:', error);
  }
}

// CHAT: on new message -> notify room members except sender
export const onChatCreated = functions.firestore
  .document('rooms/{roomId}/chats/{chatId}')
  .onCreate(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any>;
    const type = (data.type as string) || 'text';
    const senderUid = data.senderId || data.uid || data.createdBy;

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

    // Send to all room members EXCEPT the sender
    await sendToRoomExceptSender(roomId, senderUid, `💬 New message in ${roomName}`, body, {
      type: 'chat',
      roomId,
      roomName,
      screen: 'chat',
    });
  });

// EXPENSES: on create/update/delete -> notify room members except the one who made the change
export const onExpenseCreated = functions.firestore
  .document('rooms/{roomId}/expenses/{expenseId}')
  .onCreate(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any>;
    const description = (data.description as string) || 'an expense';
    const amount = data.amount != null ? Number(data.amount) : undefined;
    const currency = '₹';
    const senderUid = data.paidBy || data.createdBy || data.uid;

    // Resolve room name
    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    const body = amount != null ? `Added "${description}" - ${currency}${amount.toFixed(2)}` : `Added "${description}"`;
    await sendToRoomExceptSender(roomId, senderUid, `💰 New expense in ${roomName}`, body, {
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
    const senderUid = after.updatedBy || after.paidBy || after.createdBy || after.uid;

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoomExceptSender(roomId, senderUid, `✏️ Expense updated in ${roomName}`, `Updated "${description}"`, {
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
    // For deletes, we might not know who deleted - send to all members
    // The delete is usually tracked in activity logs if needed
    const senderUid = data?.deletedBy || data?.paidBy || data?.createdBy;

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoomExceptSender(roomId, senderUid, `🗑️ Expense deleted in ${roomName}`, `Deleted "${description}"`, {
      type: 'expense',
      roomId,
      roomName,
      screen: 'expenses',
      action: 'deleted',
    });
  });

// TASKS: on create/update/delete -> notify room members except the one who made the change
export const onTaskCreated = functions.firestore
  .document('rooms/{roomId}/tasks/{taskId}')
  .onCreate(async (snap: admin.firestore.DocumentSnapshot, ctx: functions.EventContext) => {
    const roomId = ctx.params.roomId as string;
    const data = snap.data() as Record<string, any>;
    const title = (data.title as string) || (data.name as string) || 'Task';
    const senderUid = data.createdBy || data.assignedTo || data.uid;

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoomExceptSender(roomId, senderUid, `✅ New task in ${roomName}`, `Created "${title}"`, {
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
    const senderUid = after.updatedBy || after.createdBy || after.assignedTo || after.uid;

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoomExceptSender(roomId, senderUid, `✏️ Task updated in ${roomName}`, `Updated "${title}"`, {
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
    const senderUid = data?.deletedBy || data?.createdBy;

    let roomName = 'Room';
    try {
      const roomDoc = await db.collection('rooms').doc(roomId).get();
      roomName = (roomDoc.data()?.name as string) || 'Room';
    } catch {}

    await sendToRoomExceptSender(roomId, senderUid, `🗑️ Task deleted in ${roomName}`, `Deleted "${title}"`, {
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
        // Check if user has task reminders enabled
        const userDoc = await db.collection('users').doc(uid).get();
        const userData = userDoc.data();
        
        if (!userData) continue;
        
        // Check both master toggle and task reminders toggle
        const notificationsEnabled = userData.notificationsEnabled ?? true;
        const taskRemindersEnabled = userData.taskRemindersEnabled ?? true;
        
        if (!notificationsEnabled || !taskRemindersEnabled) continue;
        
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

// =============================================
// BROADCAST NOTIFICATIONS (Admin/Announcements)
// =============================================

/**
 * Send a broadcast notification to all users
 * Can be called via HTTP or from Firebase Console
 */
export const sendBroadcastNotification = functions.https.onCall(
  async (data: { title: string; body: string; imageUrl?: string }, context) => {
    // Optional: Restrict to admin users only
    // if (!context.auth || !isAdmin(context.auth.uid)) {
    //   throw new functions.https.HttpsError('permission-denied', 'Only admins can send broadcasts');
    // }

    const { title, body, imageUrl } = data;

    if (!title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'Title and body are required');
    }

    const message: admin.messaging.Message = {
      topic: 'all_users',
      notification: {
        title,
        body,
        ...(imageUrl && { imageUrl }),
      },
      data: {
        type: 'broadcast',
        screen: 'dashboard',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'one_room_channel',
          ...(imageUrl && { imageUrl }),
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default' },
        },
      },
    };

    await messaging.send(message);
    console.log(`📢 Broadcast sent: "${title}"`);
    return { success: true, message: 'Broadcast sent to all users' };
  }
);

/**
 * Send notification to a specific room
 */
export const sendRoomNotification = functions.https.onCall(
  async (data: { roomId: string; title: string; body: string }, context) => {
    const { roomId, title, body } = data;

    if (!roomId || !title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'roomId, title, and body are required');
    }

    await sendToRoom(roomId, title, body, {
      type: 'announcement',
      roomId,
      screen: 'dashboard',
    });

    return { success: true, message: `Notification sent to room ${roomId}` };
  }
);

/**
 * HTTP endpoint for sending broadcasts (useful for external tools/scripts)
 * POST /sendBroadcast with JSON body: { "title": "...", "body": "...", "secret": "your-secret" }
 */
export const sendBroadcastHttp = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const { title, body, secret } = req.body;

  // Simple secret key protection (set this in Firebase environment config)
  const expectedSecret = process.env.BROADCAST_SECRET || 'oneroom-broadcast-2024';
  if (secret !== expectedSecret) {
    res.status(403).send('Invalid secret');
    return;
  }

  if (!title || !body) {
    res.status(400).send('Title and body are required');
    return;
  }

  const message: admin.messaging.Message = {
    topic: 'all_users',
    notification: { title, body },
    data: { type: 'broadcast', screen: 'dashboard' },
    android: { priority: 'high', notification: { channelId: 'one_room_channel' } },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  await messaging.send(message);
  res.status(200).json({ success: true, message: 'Broadcast sent' });
});
