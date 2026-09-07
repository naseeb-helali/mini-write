const {
  S3Client,
  HeadBucketCommand,
  GetObjectCommand,
  PutObjectCommand
} = require('@aws-sdk/client-s3');

const s3Client = new S3Client({
  region:
    process.env.AWS_REGION ||
    process.env.AWS_DEFAULT_REGION
});

const provider = {
  async initialize(bucketNames = []) {
    const buckets = Array.isArray(bucketNames)
      ? bucketNames
      : [bucketNames];

    for (const bucketName of buckets) {
      await s3Client.send(
        new HeadBucketCommand({
          Bucket: bucketName
        })
      );
    }

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

  async getObject(
    bucketName,
    objectName
  ) {
    const response =
      await s3Client.send(
        new GetObjectCommand({
          Bucket: bucketName,
          Key: objectName
        })
      );

    return response.Body;
  },

  async putObject(
    bucketName,
    objectName,
    data,
    metadata = {}
  ) {
    return s3Client.send(
      new PutObjectCommand({
        Bucket: bucketName,
        Key: objectName,
        Body: data,
        ContentType:
          metadata['Content-Type']
      })
    );
  }
};

module.exports = provider;