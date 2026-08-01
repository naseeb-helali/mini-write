const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const storageService = require('../services/storageService');
const queueService = require('../services/queueService');
const businessMetrics = require('../observability/businessMetrics');
const logger = require('../observability/logger');
const EVENTS = require('../observability/events');
const { buildOperationContext } = require('../observability/logContext');
const {
  executeInfrastructureOperation
} = require('../runtime/infrastructure/infrastructureBoundary');
const { DEPENDENCIES } = require('../runtime/infrastructure/dependencies');

exports.register = async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Missing fields' });
  }

  try {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = await executeInfrastructureOperation({
      req,
      dependency: DEPENDENCIES.POSTGRESQL,
      operation: async () => {
        return pool.query(
          'INSERT INTO users (username, password) VALUES ($1, $2) RETURNING id, username',
          [username, hashedPassword]
        );
      }
    });

    businessMetrics.userRegistrations.inc();

    logger.info({
      event: EVENTS.USER_REGISTERED,
      ...buildOperationContext(
        req,
        'register',
        newUser.rows[0].id
      ),
      username: newUser.rows[0].username
    });

    return res.status(201).json({
      message: 'User created',
      data: newUser.rows[0]
    });
  } catch (err) {
    if (err.code === '23505') {
      logger.warn({
        event: EVENTS.USER_REGISTRATION_FAILED,
        ...buildOperationContext(
          req,
          'register'
        ),
        username,
        reason: 'duplicate_username'
      });

      return res.status(400).json({
        error: 'Username already exists'
      });
    }

    logger.error({
      event: EVENTS.USER_REGISTRATION_FAILED,
      ...buildOperationContext(
        req,
        'register'
      ),
      username,
      error_message: err.message
    });

    return res.status(500).json({
      error: 'Server error during registration'
    });
  }
};

exports.login = async (req, res) => {
  const { username, password } = req.body;

  try {
    const user = await executeInfrastructureOperation({
      req,
      dependency: DEPENDENCIES.POSTGRESQL,
      operation: async () => {
        return pool.query(
          'SELECT * FROM users WHERE username = $1',
          [username]
        );
      }
    });

    if (user.rows.length === 0) {
      logger.warn({
        event: EVENTS.USER_LOGIN_FAILED,
        ...buildOperationContext(
          req,
          'login'
        ),
        username,
        reason: 'user_not_found'
      });

      return res.status(401).json({
        error: 'Invalid credentials'
      });
    }

    const validPass = await bcrypt.compare(password, user.rows[0].password);

    if (!validPass) {
      logger.warn({
        event: EVENTS.USER_LOGIN_FAILED,
        ...buildOperationContext(
          req,
          'login'
        ),
        username,
        reason: 'invalid_password'
      });

      return res.status(401).json({
        error: 'Invalid credentials'
      });
    }

    const token = jwt.sign(
      { id: user.rows[0].id, username: user.rows[0].username },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRY }
    );

    businessMetrics.userLogins.inc();

    logger.info({
      event: EVENTS.USER_LOGIN_SUCCESS,
      ...buildOperationContext(
        req,
        'login',
        user.rows[0].id
      ),
      username
    });

    return res.json({ token });
  } catch (err) {
    logger.error({
      event: EVENTS.USER_LOGIN_FAILED,
      ...buildOperationContext(
        req,
        'login'
      ),
      username,
      error_message: err.message
    });

    return res.status(500).json({
      error: 'Server error during login'
    });
  }
};

exports.getProfile = (req, res) => {
  res.json({
    message: 'Welcome to your secure profile',
    user: req.user
  });
};

exports.uploadID = async (req, res) => {
  try {
    businessMetrics.idUploads.inc();

    logger.info({
      event: EVENTS.ID_UPLOAD_STARTED,
      ...buildOperationContext(
        req,
        'upload_id',
        req.user.id
      )
    });

    if (!req.file) {
      return res.status(400).json({
        error: 'No file uploaded or invalid file type.'
      });
    }

    const uploadResult = await executeInfrastructureOperation({
      req,
      dependency: DEPENDENCIES.MINIO,
      operation: async () => {
        return storageService.uploadIdCard(req.file);
      }
    });

    const userId = req.user.id;
    const updateQuery =
      'UPDATE users SET id_card_url = $1 WHERE id = $2 RETURNING id, username, id_card_url';

    const dbResult = await executeInfrastructureOperation({
      req,
      dependency: DEPENDENCIES.POSTGRESQL,
      operation: async () => {
        return pool.query(
          updateQuery,
          [
            uploadResult.fileName,
            userId
          ]
        );
      }
    });

    await executeInfrastructureOperation({
      req,
      dependency: DEPENDENCIES.REDIS,
      operation: async () => {
        return queueService.addIdCardJob(
          userId,
          uploadResult.fileName
        );
      }
    });

    businessMetrics.jobsEnqueued.inc({
      job_type: 'id_card_processing'
    });

    logger.info({
      event: EVENTS.JOB_ENQUEUED,
      ...buildOperationContext(
        req,
        'upload_id',
        userId
      ),
      job_type: 'id_card_processing',
      file_name: uploadResult.fileName
    });

    businessMetrics.idUploadSuccess.inc();

    logger.info({
      event: EVENTS.ID_UPLOAD_SUCCESS,
      ...buildOperationContext(
        req,
        'upload_id',
        userId
      ),
      file_name: uploadResult.fileName
    });

    return res.status(200).json({
      message: 'ID Card uploaded. Processing started in background!',
      user: dbResult.rows[0]
    });
  } catch (err) {
    businessMetrics.idUploadFailures.inc({
      reason: err.name || 'unknown'
    });

    logger.error({
      event: EVENTS.ID_UPLOAD_FAILED,
      ...buildOperationContext(
        req,
        'upload_id',
        req.user?.id
      ),
      error_message: err.message
    });

    return res.status(500).json({
      error: 'Internal server error during upload.'
    });
  }
};
