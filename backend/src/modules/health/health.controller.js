const env = require('../../config/env');
const { getDatabaseStatus } = require('../../db/pool');
const { getFirebaseInitStatus } = require('../../config/firebase');

async function getHealth(_request, response, next) {
  try {
    response.status(200).json({
      message: 'Chat backend is running.',
      environment: env.nodeEnv,
      timestamp: new Date().toISOString(),
      database: {
        ...getDatabaseStatus(),
        connected: getDatabaseStatus().lastConnectionError === null,
      },
      firebase: getFirebaseInitStatus(),
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getHealth,
};
