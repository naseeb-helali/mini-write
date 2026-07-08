function buildJobContext(job) {
  return {
    job_id: job?.id || null,

    job_type:
      job?.name || 'process-id-card'
  };
}

function buildUserJobContext(
  job,
  userId
) {
  return {
    job_id: job?.id || null,

    job_type:
      job?.name || 'process-id-card',

    user_id:
      userId || null
  };
}

function buildProcessingContext(
  job,
  userId,
  fileName
) {
  return {
    job_id: job?.id || null,

    job_type:
      job?.name || 'process-id-card',

    user_id:
      userId || null,

    file_name:
      fileName || null
  };
}

function buildOperationContext(
  operationId,
  metadata = {}
) {
  return {
    operation_id: operationId,

    ...metadata
  };
}

module.exports = {
  buildJobContext,

  buildUserJobContext,

  buildProcessingContext,

  buildOperationContext
};