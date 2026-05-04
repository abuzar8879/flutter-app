const cors = require('cors');
const express = require('express');
const path = require('path');
const pinoHttp = require('pino-http');
const env = require('./config/env');
const logger = require('./config/logger');
const apiRoutes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middlewares/error-handler');

const app = express();

app.use(
  cors({
    origin: env.frontendOrigin,
  }),
);
app.use(express.json());
app.use(pinoHttp({ logger }));
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

app.get('/', (_request, response) => {
  response.status(200).json({
    message: 'Chat API root is available.',
  });
});

app.use('/api', apiRoutes);
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
