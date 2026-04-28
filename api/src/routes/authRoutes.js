const upload = require('../middleware/uploadMiddleware');
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// Directing requests to the relevant controller
router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/profile', authMiddleware, authController.getProfile);
router.post('/upload-id', authMiddleware, upload.single('id_card'), authController.uploadID);

module.exports = router;