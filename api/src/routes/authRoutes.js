const express = require('express');
const upload = require('../middleware/uploadMiddleware');
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const runtimeOperationResolution = require('../runtime/middleware/runtimeOperationResolution');
const {
  OPERATIONS,
  OPERATION_CATEGORIES
} = require('../runtime/context/operationContext');
const runtimeStateActivation = require('../runtime/middleware/runtimeStateActivation');

const router = express.Router();

router.post(
  '/register',
  runtimeOperationResolution({
    id: OPERATIONS.USER_REGISTER,
    category: OPERATION_CATEGORIES.AUTH
  }),
  runtimeStateActivation,
  authController.register
);

router.post(
  '/login',
  runtimeOperationResolution({
    id: OPERATIONS.USER_LOGIN,
    category: OPERATION_CATEGORIES.AUTH
  }),
  runtimeStateActivation,
  authController.login
);

router.get(
  '/profile',
  authMiddleware,
  runtimeOperationResolution({
    id: OPERATIONS.USER_PROFILE,
    category: OPERATION_CATEGORIES.USER
  }),
  runtimeStateActivation,
  authController.getProfile
);

router.post(
  '/upload-id',
  authMiddleware,
  runtimeOperationResolution({
    id: OPERATIONS.ID_UPLOAD,
    category: OPERATION_CATEGORIES.STORAGE,
    characteristics: {
      requiresDatabase: true,
      requiresStorage: true,
      asynchronous: true
    }
  }),
  upload.single('id_card'),
  runtimeStateActivation,
  authController.uploadID
);

module.exports = router;
