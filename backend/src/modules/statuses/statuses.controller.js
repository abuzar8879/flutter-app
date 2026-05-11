const statusesService = require('./statuses.service');

async function createStatus(request, response, next) {
  try {
    const status = await statusesService.createStatus(request.user.sub, request.body);
    response.status(201).json({ status });
  } catch (error) {
    next(error);
  }
}

async function listStatuses(_request, response, next) {
  try {
    const statuses = await statusesService.listStatuses();
    response.status(200).json({ statuses });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  createStatus,
  listStatuses,
};
