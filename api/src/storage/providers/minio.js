const Minio = require('minio');

const minioClient = new Minio.Client({
  endPoint: process.env.MINIO_ENDPOINT,
  port: parseInt(process.env.MINIO_PORT, 10),
  useSSL: false,
  accessKey: process.env.MINIO_ROOT_USER,
  secretKey: process.env.MINIO_ROOT_PASSWORD
});

const provider = {
  async initialize(bucketName) {
    await minioClient.listBuckets();
    return true;
  },

  async checkHealth(bucketName) {
    await minioClient.listBuckets();
    return true;
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
  },

  async getObject(
    bucketName,
    objectName
  ) {
    return minioClient.getObject(
      bucketName,
      objectName
    );
  }
};

module.exports = provider;