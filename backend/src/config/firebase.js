const admin = require('firebase-admin');
const env = require('./env');

let isInitialized = false;
let initError = null;

function initializeFirebase() {
  if (isInitialized) return;
  try {
    const options = {};

    if (env.firebaseServiceAccountJson) {
      options.credential = admin.credential.cert(JSON.parse(env.firebaseServiceAccountJson));
    }

    if (env.firebaseDatabaseUrl) {
      options.databaseURL = env.firebaseDatabaseUrl;
    }

    admin.initializeApp(options);
    isInitialized = true;
    initError = null;
    console.log('Firebase Admin initialized.');
  } catch (error) {
    initError = error;
    console.warn('Firebase Admin failed to initialize. Push notifications will not be sent.', error.message);
  }
}

async function sendPushNotification(fcmToken, title, body, data = {}) {
  if (!isInitialized || !fcmToken) return;

  try {
    const sanitizedData = Object.fromEntries(
      Object.entries(data)
        .filter(([, value]) => value != null)
        .map(([key, value]) => [key, String(value)]),
    );

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: sanitizedData,
    });
  } catch (error) {
    console.error('Failed to send FCM push notification:', error.message);
  }
}

module.exports = {
  initializeFirebase,
  getFirebaseInitStatus: () => ({
    initialized: isInitialized,
    error: initError ? initError.message : null,
  }),
  sendPushNotification,
};
