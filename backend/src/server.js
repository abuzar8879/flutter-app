const http = require('http');
const app = require('./app');
const env = require('./config/env');
const logger = require('./config/logger');
const { initializeSocket } = require('./socket');
const { initializeFirebase, getFirebaseInitStatus } = require('./config/firebase');

async function startServer() {
  const server = http.createServer(app);
  initializeSocket(server);
  
  initializeFirebase();
  logger.info({ firebase: getFirebaseInitStatus() }, 'Firebase initialization status.');

  server.listen(env.port, () => {
    logger.info({ port: env.port }, 'Backend server started.');
  });
}

startServer();
