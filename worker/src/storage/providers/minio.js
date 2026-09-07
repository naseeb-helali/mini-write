const Minio = require('minio');

const minioClient = new Minio.Client({
  endPoint:
    process.env.MINIO_ENDPOINT ||
    'mw-storage',

  port:
    parseInt(process.env.MINIO_PORT, 10) ||
    9000,

  useSSL: false,

  accessKey:
    process.env.MINIO_ROOT_USER,

  secretKey:
    process.env.MINIO_ROOT_PASSWORD
});

const provider = {
  async initialize(bucketNames = []) {
    await minioClient.listBuckets();
    return true;
  },

  async checkHealth(bucketName) {
    await minioClient.listBuckets();
    return true;
  },

  async getObject(
    bucketName,
    objectName
  ) {
    return minioClient.getObject(
      bucketName,
      objectName
    );
  },

  async putObject(
    bucketName,
    objectName,
    data,
    metadata
  ) {
    return minioClient.putObject(
      bucketName,
      objectName,
      data,
      metadata
    );
  }
};

module.exports = provider;