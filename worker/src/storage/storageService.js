const storageProvider =
  require('./index');

const INPUT_BUCKET =
  process.env.STORAGE_INPUT_BUCKET ||
  'user-documents';

const OUTPUT_BUCKET =
  process.env.STORAGE_OUTPUT_BUCKET ||
  'processed-docs';

// =========================================================
// Storage Health
// =========================================================

const checkHealth = async () => {
  return storageProvider.checkHealth();
};

// =========================================================
// Object Operations
// =========================================================

const getObject = async (
  bucketName,
  objectName
) => {
  return storageProvider.getObject(
    bucketName,
    objectName
  );
};

const putObject = async (
  bucketName,
  objectName,
  data,
  metadata
) => {
  return storageProvider.putObject(
    bucketName,
    objectName,
    data,
    metadata
  );
};

module.exports = {
  checkHealth,
  getObject,
  putObject,
  INPUT_BUCKET,
  OUTPUT_BUCKET
};