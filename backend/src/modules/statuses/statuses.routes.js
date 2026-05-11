const express = require('express');
const { authenticate } = require('../../middlewares/authenticate');
const statusesController = require('./statuses.controller');

const router = express.Router();

router.get('/', authenticate, statusesController.listStatuses);
router.post('/', authenticate, statusesController.createStatus);

module.exports = router;
