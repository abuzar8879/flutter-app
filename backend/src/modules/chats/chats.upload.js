const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const chatUploadDirectory = path.join(process.cwd(), 'uploads', 'chat');
fs.mkdirSync(chatUploadDirectory, { recursive: true });

const storage = multer.diskStorage({
  destination: (_request, _file, callback) => {
    callback(null, chatUploadDirectory);
  },
  filename: (_request, file, callback) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    callback(null, `${Date.now()}-${crypto.randomUUID()}${extension || '.jpg'}`);
  },
});

const uploadChatImage = multer({ storage });
const uploadChatAudio = multer({ storage });

module.exports = {
  uploadChatAudio,
  uploadChatImage,
};
