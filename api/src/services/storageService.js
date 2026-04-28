const minioClient = require('../config/storage');
const crypto = require('crypto');

const BUCKET_NAME = process.env.MINIO_BUCKET || 'user-documents';

exports.initStorage = async () => {
  try {
    const exists = await minioClient.bucketExists(BUCKET_NAME);
    if (!exists) {
      await minioClient.makeBucket(BUCKET_NAME, 'us-east-1');
      console.log(`[Storage] Bucket '${BUCKET_NAME}' created successfully.`);
    } else {
      console.log(`[Storage] Bucket '${BUCKET_NAME}' is ready.`);
    }
  } catch (err) {
    console.error(`[Storage Error] Could not initialize MinIO: ${err.message}`);
    throw err;
  }
};

// Function to generate a unique file name
const generateFileName = (originalName) => {
    const fileExtension = originalName.split('.').pop();
    const randomName = crypto.randomBytes(16).toString('hex');
    return `${randomName}.${fileExtension}`;
};

// Upload function
exports.uploadIdCard = async (file) => {
    const fileName = generateFileName(file.originalname);
    const metaData = { 'Content-Type': file.mimetype };

    // Upload the file to MinIO
    await minioClient.putObject(BUCKET_NAME, fileName, file.buffer, metaData);

    return {
        fileName: fileName,
        bucket: BUCKET_NAME
    };
};
