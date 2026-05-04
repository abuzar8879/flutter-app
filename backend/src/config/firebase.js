const admin = require('firebase-admin');

let isInitialized = false;

function initializeFirebase() {
  if (isInitialized) return;
  try {
    // Note: The user needs to set GOOGLE_APPLICATION_CREDENTIALS environment variable
    // or pass the service account key path here.
    admin.initializeApp();
    isInitialized = true;
    console.log('Firebase Admin initialized.');
  } catch (error) {
    console.warn('Firebase Admin failed to initialize. Push notifications will not be sent.', error.message);
  }
}

async function sendPushNotification(fcmToken, title, body, data = {}) {
  if (!isInitialized || !fcmToken) return;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
    });
  } catch (error) {
    console.error('Failed to send FCM push notification:', error.message);
  }
}

module.exports = {
  initializeFirebase,
  sendPushNotification,
};
