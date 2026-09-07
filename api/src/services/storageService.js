const storageProvider = require('../storage');
const crypto = require('crypto');

const BUCKET_NAME =
  process.env.STORAGE_INPUT_BUCKET || 'user-documents';

const generateFileName = (originalName) => {
  const fileExtension = originalName.split('.').pop();
  
  const randomName = crypto.randomBytes(16).toString('hex');

  return `${randomName}.${fileExtension}`;
};

exports.uploadIdCard = async (file) => {
  const fileName =
    generateFileName(file.originalname);

  const metaData = {
    'Content-Type': file.mimetype
  };

  await storageProvider.putObject(
    BUCKET_NAME,
    fileName,
    file.buffer,
    metaData
  );

  return {
    fileName,
    bucket: BUCKET_NAME
  };
};