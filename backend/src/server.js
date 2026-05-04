const http = require('http');
const app = require('./app');
const env = require('./config/env');
const logger = require('./config/logger');
const { getDatabaseStatus, verifyDatabaseConnection } = require('./db/pool');
const { ensureDatabaseSchema } = require('./db/schema');
const { initializeSocket } = require('./socket');

async function startServer() {
  const database = await verifyDatabaseConnection();

  if (!database.connected) {
    logger.warn({ database: getDatabaseStatus() }, 'Database connection is not ready. API will continue with health checks only.');
  } else {
    await ensureDatabaseSchema();
  }

  const server = http.createServer(app);
  initializeSocket(server);
  
  const { initializeFirebase } = require('./config/firebase');
  initializeFirebase();

  server.listen(env.port, () => {
    logger.info({ port: env.port }, 'Backend server started.');
  });
}

startServer();
