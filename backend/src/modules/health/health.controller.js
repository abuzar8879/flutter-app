const env = require('../../config/env');
const { getFirebaseInitStatus } = require('../../config/firebase');

async function getHealth(_request, response, next) {
  try {
    response.status(200).json({
      message: 'Chat backend is running.',
      environment: env.nodeEnv,
      timestamp: new Date().toISOString(),
      firebase: getFirebaseInitStatus(),
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getHealth,
};
