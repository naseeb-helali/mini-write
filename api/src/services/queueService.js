const { Queue } = require('bullmq');
const redisConnection = require('../config/redis');

// Create a queue named 'image-processing' (must match the queue name in Worker)
const imageQueue = new Queue('image-processing', {
    connection: redisConnection
});

// Sending an image processing task to the queue

exports.addIdCardJob = async (userId, fileName) => {
    try {
        const job = await imageQueue.add(
            'process-id-card',
            {
                userId: userId,
                fileName: fileName
            },
            {
                // 🔥 Idempotency Key (prevents duplicate jobs)
                jobId: `${userId}-${fileName}`,

                // Retry strategy
                attempts: parseInt(process.env.WORKER_RETRY_LIMIT) || 3,
                backoff: {
                    type: 'exponential',
                    delay: 1000
                },

                // Cleanup strategy
                removeOnComplete: true,
                removeOnFail: false
            }
        );

        console.log(`📡 [Queue] Job added: ${job.id} for user ${userId}`);
        return job;

    } catch (err) {
        // 🔥 BullMQ throws if jobId already exists
        if (err.message.includes('Job already exists')) {
            console.warn(`⚠️ [Queue] Duplicate job prevented for user ${userId}`);
            return { skipped: true };
        }

        console.error('❌ [Queue Error] Could not add job to Redis:', err.message);
    }
};
