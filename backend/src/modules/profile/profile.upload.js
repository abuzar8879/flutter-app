const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const multer = require('multer');

const profileUploadDirectory = path.join(process.cwd(), 'uploads', 'profile');
fs.mkdirSync(profileUploadDirectory, { recursive: true });

const storage = multer.diskStorage({
  destination: (_request, _file, callback) => {
    callback(null, profileUploadDirectory);
  },
  filename: (_request, file, callback) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    const safeExtension = extension || '.jpg';
    callback(null, `${Date.now()}-${crypto.randomUUID()}${safeExtension}`);
  },
});

const uploadProfileImage = multer({ storage });

module.exports = {
  uploadProfileImage,
};
