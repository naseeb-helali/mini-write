const {
  S3Client,
  HeadBucketCommand,
  PutObjectCommand,
  GetObjectCommand
} = require('@aws-sdk/client-s3');

const region =
  process.env.AWS_REGION ||
  process.env.AWS_DEFAULT_REGION;

const s3Client = new S3Client({
  region
});

const provider = {
  async initialize(bucketName) {
    await s3Client.send(
      new HeadBucketCommand({
        Bucket: bucketName
      })
    );

    return true;
  },

  async checkHealth(bucketName) {
    await s3Client.send(
      new HeadBucketCommand({
        Bucket: bucketName
      })
    );

    return true;
  },

  async putObject(bucketName, objectName, data, metadata = {}) {
    return s3Client.send(
      new PutObjectCommand({
        Bucket: bucketName,
        Key: objectName,
        Body: data,
        ContentType: metadata['Content-Type']
      })
    );
  },

  async getObject(bucketName, objectName) {
    const response = await s3Client.send(
      new GetObjectCommand({
        Bucket: bucketName,
        Key: objectName
      })
    );

    return response.Body;
  }
};

module.exports = provider;