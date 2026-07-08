const sharp = require('sharp');
const minioClient = require('../config/storage');
const pool = require('../config/db');
const logger = require('../observability/logger');
const EVENTS = require('../observability/events');
const {
  buildProcessingContext,
  buildOperationContext
} = require('../observability/logContext');
const {
  storageOperationsTotal,
  storageDuration,
  databaseOperationsTotal,
  databaseDuration,
  fileSize
} = require('../observability/metrics');
const {
  businessIdCardsVerifiedTotal,
  businessIdCardsSkippedTotal,
  imageProcessingDuration
} = require('../observability/businessMetrics');


const processIdCard = async (job) => {
const { fileName, userId } = job.data;

const bucketName = process.env.MINIO_BUCKET_NAME;
const outputBucket = process.env.MINIO_PROCESSED_BUCKET;

if (!bucketName || !outputBucket) {
    throw new Error("Storage configuration missing in environment variables");
}

const processedFileName = `thumb_${fileName}`;

logger.info({
    event:
        EVENTS.IMAGE_PROCESSING_STARTED,
    ...buildProcessingContext(
        job,
        userId,
        fileName
    )
});

let shouldProcess = false;

// =========================================================
// 🔷 Phase 1: Lock + Decision (Short Transaction)
// =========================================================
const client = await pool.connect();

try {
    await client.query('BEGIN');

    const result = await client.query(
        `SELECT identity_status FROM users WHERE id = $1 FOR UPDATE`,
        [userId]
    );

    const currentStatus = result.rows[0]?.identity_status;

    if (currentStatus === 'verified' || currentStatus === 'processing') {
        logger.warn({
            event:
                EVENTS.PROCESSING_ALREADY_COMPLETED,
            ...buildProcessingContext(
                job,
                userId,
                fileName
            )
        });

        await client.query('COMMIT');
        return { skipped: true };
    }

    // 🔥 Conditional update (extra safety)
    const updateResult = await client.query(
        `UPDATE users
            SET identity_status = 'processing'
            WHERE id = $1 AND identity_status = 'pending'
            RETURNING *`,
        [userId]
    );

    if (updateResult.rowCount === 0) {
        logger.warn({
            event:
                EVENTS.RACE_CONDITION_AVOIDED,
            ...buildProcessingContext(
                job,
                userId,
                fileName
            )
        });

        await client.query('COMMIT');

        businessIdCardsSkippedTotal.inc({
            reason: 'already_verified or already_processing or race_condition'
        });

        return { skipped: true };
    }

    shouldProcess = true;

    await client.query('COMMIT');

    } catch (err) {
        await client.query('ROLLBACK');
        client.release();

        databaseOperationsTotal.inc({
            operation: 'update_user',
            status: 'failed'
            });
        throw err;
    } finally {
        client.release();
    }

if (!shouldProcess) return;

// =========================================================
// 🔷 Phase 2: Processing (NO DB TRANSACTION)
// =========================================================

logger.info({
  event:
    EVENTS.STORAGE_DOWNLOAD_STARTED,
...buildProcessingContext(
    job,
    userId,
    fileName
)
});

// 🔥 Safe streaming with size protection
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
let totalSize = 0;

const storageReadTimer =
    storageDuration.startTimer({
        operation: 'download'
    });

const dataStream = await minioClient.getObject(
    bucketName,
    fileName
    );

storageOperationsTotal.inc({
    operation: 'download',
    status: 'success'
    });

storageReadTimer();

logger.info({
    event:
        EVENTS.STORAGE_DOWNLOAD_COMPLETED,
    ...buildProcessingContext(
        job,
        userId,
        fileName
    )
});

const chunks = [];

for await (const chunk of dataStream) {
    totalSize += chunk.length;

    if (totalSize > MAX_FILE_SIZE) {
        throw new Error("File too large - potential memory risk");
    }

    chunks.push(chunk);
}

const buffer = Buffer.concat(chunks);

fileSize.observe(
    {
        job_type: 'process-id-card'
    },
    buffer.length
    );

const processedBuffer = await sharp(buffer)
    .resize(800, 600, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80, progressive: true })
    .rotate()
    .toBuffer();

logger.info({
    event:
        EVENTS.STORAGE_UPLOAD_STARTED,
    ...buildProcessingContext(
        job,
        userId,
        fileName
    )
});

const storageWriteTimer =
    storageDuration.startTimer({
        operation: 'upload'
    });

await minioClient.putObject(
    outputBucket,
    processedFileName,
    processedBuffer,
    { 'Content-Type': 'image/jpeg' }
);

storageOperationsTotal.inc({
    operation: 'upload',
    status: 'success'
    });

storageWriteTimer();

logger.info({
  event:
        EVENTS.STORAGE_UPLOAD_COMPLETED,
    ...buildProcessingContext(
        job,
        userId,
        fileName
    )
});

// =========================================================
// 🔷 Phase 3: Final Commit (Short Transaction)
// =========================================================
const client2 = await pool.connect();

try {

    logger.info({
        event:
            EVENTS.DATABASE_UPDATE_STARTED,
        ...buildOperationContext(
            'update_user'
        ),
        ...buildProcessingContext(
            job,
            userId,
            fileName
        )
    });

    await client2.query('BEGIN');

    const dbTimer =
        databaseDuration.startTimer({
            operation: 'update_user'
        });

    await client2.query(
        `UPDATE users
            SET document_url = $1, identity_status = 'verified'
            WHERE id = $2`,
        [processedFileName, userId]
    );

    databaseOperationsTotal.inc({
        operation: 'update_user',
        status: 'success'
        });

dbTimer();

logger.info({
  event:
        EVENTS.DATABASE_UPDATE_COMPLETED,
    ...buildOperationContext(
        'update_user'
    ),
    ...buildProcessingContext(
        job,
        userId,
        fileName
    )
});

    await client2.query('COMMIT');

    logger.info({
        event:
            EVENTS.IMAGE_PROCESSING_COMPLETED,
        ...buildProcessingContext(
            job,
            userId,
            fileName
        )
    });

    businessIdCardsVerifiedTotal.inc();

    return {
        success: true,
        userId,
        file: processedFileName
    };

} catch (err) {
    await client2.query('ROLLBACK');

    storageOperationsTotal.inc({
        operation: 'upload',
        status: 'failed'
        });

    throw err;
} finally {
    client2.release();
}
};

module.exports = { processIdCard };