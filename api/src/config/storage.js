const Minio = require('minio');

const minioClient = new Minio.Client({
  endPoint: process.env.MINIO_ENDPOINT, // 'mw-storage' from docker-compose
  port: parseInt(process.env.MINIO_PORT), // 9000
  useSSL: false,
  accessKey: process.env.MINIO_ROOT_USER,
  secretKey: process.env.MINIO_ROOT_PASSWORD,
});

module.exports = minioClient;
