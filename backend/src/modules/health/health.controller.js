const env = require('../../config/env');
const { verifyDatabaseConnection } = require('../../db/pool');

async function getHealth(_request, response, next) {
  try {
    const database = await verifyDatabaseConnection();

    response.status(200).json({
      message: 'Chat backend is running.',
      environment: env.nodeEnv,
      timestamp: new Date().toISOString(),
      database,
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getHealth,
};
