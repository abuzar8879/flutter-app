const path = require('path');
const fs = require('fs');
const multer = require('multer');

const uploadPath = path.join(process.cwd(), 'uploads', 'group');
fs.mkdirSync(uploadPath, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadPath),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext && ext.length <= 10 ? ext : '';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`);
  },
});

const uploadGroupImage = multer({ storage });

module.exports = {
  uploadGroupImage,
};

