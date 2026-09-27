const providerName = (
  process.env.STORAGE_PROVIDER ||
  'minio'
).toLowerCase();

const providers = {
  minio: () => require('./providers/minio'),
  s3: () => require('./providers/s3')
};

const loadProvider = providers[providerName];

if (!loadProvider) {
  throw new Error(
    `Unsupported storage provider: ${providerName}`
  );
}

module.exports = loadProvider();