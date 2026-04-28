const multer = require('multer');

// Temporarily store the file in memory before uploading it to MinIO
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
    // Only images (JPG, PNG) are allowed
    if (file.mimetype === 'image/jpeg' || file.mimetype === 'image/png') {
        cb(null, true);
    } else {
        cb(new Error('Invalid file type. Only JPEG and PNG are allowed!'), false);
    }
};

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 1024 * 1024 * 2 // Maximum 2 MB
    },
    fileFilter: fileFilter
});

module.exports = upload;
