const express = require('express');
const { authenticate } = require('../../middlewares/authenticate');
const friendsController = require('./friends.controller');

const router = express.Router();

// Phase 5: Friend requests
router.post('/requests', authenticate, friendsController.sendRequest);
router.patch('/requests/:id', authenticate, friendsController.respondToRequest);
router.get('/requests/pending', authenticate, friendsController.getPendingRequests);

// Phase 6: My friends
router.get('/', authenticate, friendsController.getMyFriends);

module.exports = router;
