function notFoundHandler(_request, response) {
  response.status(404).json({
    message: 'Route not found.',
  });
}

function errorHandler(error, _request, response, _next) {
  const statusCode = error.statusCode ?? 500;

  response.status(statusCode).json({
    message: statusCode === 500 ? 'Internal server error.' : error.message,
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
