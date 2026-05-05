const logger = require('../config/logger');

function notFoundHandler(_request, response) {
  response.status(404).json({
    message: 'Route not found.',
  });
}

function errorHandler(error, request, response, _next) {
  const statusCode = error.statusCode ?? 500;
  const isServerError = statusCode >= 500;

  if (isServerError) {
    logger.error(
      {
        err: {
          message: error.message,
          stack: error.stack,
          code: error.code ?? null,
        },
        request: {
          method: request.method,
          url: request.originalUrl,
        },
      },
      'Unhandled server error.',
    );
  }

  response.status(statusCode).json({
    message: statusCode === 500 ? 'Internal server error.' : error.message,
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
