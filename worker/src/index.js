const { Worker } = require('bullmq');
const redisConnection = require('./config/redis');
const { processIdCard } = require('./processors/imageProcessor');


  // The Worker Instance
 // Listens to the 'image-processing' queue and executes jobs.

const worker = new Worker(
  'image-processing', // Target Queue Name
  async (job) => {
    // This is the logic executed for every job in the queue
    return await processIdCard(job);
  },
  {
    connection: redisConnection,
    concurrency: parseInt(process.env.WORKER_CONCURRENCY) || 2, // Process up to 2 images simultaneously (CPU Friendly)
    removeOnComplete: { count: 100 }, // Keep only the last 100 successful jobs in Redis
    removeOnFail: { count: 500 },     // Keep history of failed jobs for debugging
  }
);

// --- Professional Event Monitoring ---

worker.on('active', (job) => {
  console.log(`🏃 [Worker] Job ${job.id} started processing...`);
});

worker.on('completed', (job, returnValue) => {
  console.log(`✨ [Worker] Job ${job.id} completed successfully! Result:`, returnValue);
});

worker.on('failed', (job, err) => {
  console.error(`💥 [Worker] Job ${job.id} failed:`, err.message);

  // Professional Tip: Here you can send an alert to Slack/Discord in production
});

console.log('👷 [Worker] Microservice is now ONLINE and waiting for jobs...');

// Graceful Shutdown: Handle system signals (Docker stop/restart)
process.on('SIGTERM', async () => {
  console.info('🛑 [Worker] SIGTERM signal received. Closing worker...');
  await worker.close();
  process.exit(0);
});
