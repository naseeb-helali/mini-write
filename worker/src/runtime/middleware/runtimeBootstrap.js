const {
  createExecutionContext
} = require('../context/executionContext');

function runtimeBootstrap(job) {

  if (!job) {
    throw new Error(
      'BullMQ job is required.'
    );
  }

  const runtime =
    createExecutionContext();

  runtime.initialize();

  runtime.attachMetadata({

    jobId:
      job.id,

    queue:
      job.queueName,

    jobName:
      job.name,

    attemptsMade:
      job.attemptsMade,

    maxAttempts:
      job.opts?.attempts ?? 1,

    priority:
      job.opts?.priority ?? null,

    delay:
      job.opts?.delay ?? 0,

    timestamp:
      job.timestamp,

    processedOn:
      job.processedOn ?? null

  });

  const runtimeIntegrity =
    Object.freeze({

      runtime,

      executionId:
        runtime
          .getIdentity()
          .executionId,

      requestId:
        runtime
          .getIdentity()
          .requestId

    });

  return {

    runtime,

    runtimeIntegrity

  };

}

module.exports =
  runtimeBootstrap;