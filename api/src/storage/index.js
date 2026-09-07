const minioProvider =
  require('./providers/minio');

const s3Provider =
  require('./providers/s3');

const providers = {
  minio: minioProvider,
  s3: s3Provider
};

const providerName = (
  process.env.STORAGE_PROVIDER ||
  'minio'
).toLowerCase();

const provider =
  providers[providerName];

if (!provider) {
  throw new Error(
    `Unsupported storage provider: ${providerName}`
  );
}

module.exports = provider;