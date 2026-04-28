const sharp = require('sharp');
const minioClient = require('../config/storage');
const pool = require('../config/db');

const processIdCard = async (job) => {
    const { fileName, userId } = job.data;

    const bucketName = process.env.MINIO_BUCKET_NAME;
    const outputBucket = process.env.MINIO_PROCESSED_BUCKET;

    if (!bucketName || !outputBucket) {
        throw new Error("Storage configuration missing in environment variables");
    }

    const processedFileName = `thumb_${fileName}`;

    console.log(`🚀 [Processor] Job started for User: ${userId}`);

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
            console.log(`⚠️ [Processor] Already processed or in progress. Skipping...`);
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
            console.log(`⚠️ [Processor] Race condition avoided. Another worker took the job.`);
            await client.query('COMMIT');
            return { skipped: true };
        }

        shouldProcess = true;

        await client.query('COMMIT');

    } catch (err) {
        await client.query('ROLLBACK');
        client.release();
        throw err;
    } finally {
        client.release();
    }

    if (!shouldProcess) return;

    // =========================================================
    // 🔷 Phase 2: Processing (NO DB TRANSACTION)
    // =========================================================

    console.log(`🛠️ [Processor] Processing image...`);

    // 🔥 Safe streaming with size protection
    const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
    let totalSize = 0;

    const dataStream = await minioClient.getObject(bucketName, fileName);
    const chunks = [];

    for await (const chunk of dataStream) {
        totalSize += chunk.length;

        if (totalSize > MAX_FILE_SIZE) {
            throw new Error("File too large - potential memory risk");
        }

        chunks.push(chunk);
    }

    const buffer = Buffer.concat(chunks);

    const processedBuffer = await sharp(buffer)
        .resize(800, 600, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 80, progressive: true })
        .rotate()
        .toBuffer();

    await minioClient.putObject(
        outputBucket,
        processedFileName,
        processedBuffer,
        { 'Content-Type': 'image/jpeg' }
    );

    console.log(`📦 [Processor] Upload completed`);

    // =========================================================
    // 🔷 Phase 3: Final Commit (Short Transaction)
    // =========================================================
    const client2 = await pool.connect();

    try {
        await client2.query('BEGIN');

        await client2.query(
            `UPDATE users
             SET document_url = $1, identity_status = 'verified'
             WHERE id = $2`,
            [processedFileName, userId]
        );

        await client2.query('COMMIT');

        console.log(`✅ [Processor] Completed successfully`);

        return {
            success: true,
            userId,
            file: processedFileName
        };

    } catch (err) {
        await client2.query('ROLLBACK');
        throw err;
    } finally {
        client2.release();
    }
};

module.exports = { processIdCard };