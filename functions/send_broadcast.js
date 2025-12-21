const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'one-room-2c1a6'
});

const message = {
    topic: 'all_users',
    notification: {
        title: '🚀 New Update Available!',
        body: 'OneRoom v1.0.0+5 is live! Enjoy Guest Payments, Task Swapping, and our new Analytics shortcut. Update now from the Play Store!'
    },
    data: {
        type: 'broadcast',
        screen: 'dashboard'
    },
    android: {
        priority: 'high',
        notification: {
            channelId: 'one_room_channel'
        }
    },
    apns: {
        payload: {
            aps: { sound: 'default' }
        }
    }
};

console.log('📤 Sending broadcast notification...');

admin.messaging().send(message)
    .then((response) => {
        console.log('✅ Successfully sent message:', response);
        process.exit(0);
    })
    .catch((error) => {
        console.error('❌ Error sending message:', error);
        process.exit(1);
    });
