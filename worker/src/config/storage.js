const Minio = require('minio');

  // MinIO Storage Client Configuration
 // Professional Setup for Background File Processing
const minioClient = new Minio.Client({
    endPoint: process.env.MINIO_ENDPOINT || 'mw-storage',
    port: parseInt(process.env.MINIO_PORT) || 9000,
    useSSL: false, // Set to true if using HTTPS in production
    accessKey: process.env.MINIO_ROOT_USER,
    secretKey: process.env.MINIO_ROOT_PASSWORD
});

/**
 * Security & Availability Check
 * Verifies if the required buckets exist before the worker starts processing
 */
const verifyStorage = async () => {
    const buckets = ['user-documents', 'processed-docs'];

    for (const bucket of buckets) {
        try {
            const exists = await minioClient.bucketExists(bucket);
            if (!exists) {
                console.warn(`⚠️ [Worker-Storage] Bucket '${bucket}' missing. Creating now...`);
                await minioClient.makeBucket(bucket);
                console.log(`✅ [Worker-Storage] Bucket '${bucket}' created successfully.`);
            }
        } catch (err) {
            console.error(`❌ [Worker-Storage] Error verifying bucket '${bucket}':`, err.message);
        }
    }
};

// Execute verification immediately (Self-Healing Pattern)
verifyStorage().then(() => {
    console.log('📦 [Worker-Storage] MinIO Client is ready and buckets are verified.');
});

module.exports = minioClient;
