const http = require('http');
const { Worker, Queue } = require('bullmq');
const redisConnection = require('./config/redis');
const { processIdCard } = require('./processors/imageProcessor');
const { register } = require('./observability/registry');
const {
  jobsProcessedTotal,
  jobFailuresTotal,
  jobsRetriedTotal,

  jobsActive,
  queueDepth,
  queuePaused,

  jobDuration
} = require('./observability/metrics');
const logger = require(
  './observability/logger'
);
const EVENTS = require(
  './observability/events'
);
const {
  buildJobContext
} = require(
  './observability/logContext'
);
// The Worker Instance
// Listens to the 'image-processing' queue and executes jobs.

const jobTimers = new Map();

const queue = new Queue(
    'image-processing',
    {
      connection: redisConnection
    }
  );

const worker = new Worker(
  'image-processing',

  async (job) => {
    return processIdCard(job);
  },

  {
    connection: redisConnection,

    concurrency: parseInt(process.env.WORKER_CONCURRENCY) || 2,

    removeOnComplete: {
      count: 100
    },

    removeOnFail: {
      count: 500
    }
  }
);

// --- Professional Event Monitoring ---

worker.on('active', (job) => {
  logger.info({
    event:
      EVENTS.JOB_STARTED,
    ...buildJobContext(job)
  });

  jobsActive.inc({
    queue_name: 'image-processing'
  });

  jobTimers.set(job.id, process.hrtime.bigint());
});

worker.on('completed', (job, result) => {
  logger.info({
    event:
      EVENTS.JOB_COMPLETED,
    ...buildJobContext(job),
    result
  });

  jobsActive.dec({
    queue_name: 'image-processing'
  });

  jobsProcessedTotal.inc({
    job_type: job.name || 'image-processing',
    status: 'success'
  });

  const start = jobTimers.get(job.id);

  if (start) {
    const duration =
      Number(process.hrtime.bigint() - start) / 1e9;

    jobDuration.observe(
      {
        job_type: job.name || 'image-processing',
        status: 'success'
      },
      duration
    );

    jobTimers.delete(job.id);
  }
});

worker.on('failed', (job, err) => {
  logger.error({
    event:
      EVENTS.JOB_FAILED,
    ...buildJobContext(job),
    error:
      err.message,
    error_type:
      err.name || 'unknown'
  });

  jobsActive.dec({
    queue_name: 'image-processing'
  });

  jobFailuresTotal.inc({
    job_type: job?.name || 'image-processing',
    error_type: err.name || 'unknown'
  });

  jobsProcessedTotal.inc({
    job_type: job?.name || 'image-processing',
    status: 'failed'
  });

  const start = jobTimers.get(job?.id);

  if (start) {
    const duration =
      Number(process.hrtime.bigint() - start) / 1e9;

    jobDuration.observe(
      {
        job_type: job?.name || 'image-processing',
        status: 'failed'
      },
      duration
    );

    jobTimers.delete(job?.id);
  }

  if (
    job &&
    job.attemptsMade > 0 &&
    job.attemptsMade < job.opts.attempts
  ) {
    jobsRetriedTotal.inc({
      job_type: job.name || 'image-processing'
    });
  }
});

logger.info({
  event:
    EVENTS.WORKER_STARTED
});

setInterval(async () => {
  try {

    const waiting =
      await queue.getWaitingCount();

    const paused =
      await queue.isPaused();

    queueDepth.set(
      {
        queue_name: 'image-processing'
      },
      waiting
    );

    queuePaused.set(
      {
        queue_name: 'image-processing'
      },
      paused ? 1 : 0
    );

  } catch (err) {

    console.error(
      '[Queue Metrics Poller]',
      err.message
    );
  }

}, 15000);

// Graceful Shutdown: Handle system signals (Docker stop/restart)

process.on('SIGTERM', async () => {
  logger.warn({
    event:
      EVENTS.WORKER_STOPPING
  });

  await worker.close();

  process.exit(0);
});

const metricsServer = http.createServer(async (req, res) => {
  if (req.url !== '/metrics') {
    res.writeHead(404);
    return res.end();
  }

  res.writeHead(200, {
    'Content-Type': register.contentType
  });

  res.end(await register.metrics());
});

metricsServer.listen(9464, () => {
  console.log('Metrics server listening on port 9464');
});