const pino = require('pino');
const env = require('./env');

const logger = pino({
  level: env.nodeEnv === 'development' ? 'debug' : 'info',
  transport:
    env.nodeEnv === 'development'
      ? {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'SYS:standard',
          },
        }
      : undefined,
});

module.exports = logger;
