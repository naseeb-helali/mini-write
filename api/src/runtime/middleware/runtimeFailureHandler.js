const logger = require('../../observability/logger');
const EVENTS = require('../../observability/events');
const { EXECUTION_STATES } = require('../context/executionContext');
const { classifyFailure } = require('../reliability/failureClassifier');

function getStatusCode(error) {
  if (error?.name === 'RuntimeTimeoutError') {
    return 504;
  }

  return error?.statusCode || error?.status || 500;
}

function runtimeFailureHandler(error, req, res, next) {
  if (req.runtime) {
    const alreadyRegistered =
      typeof req.runtime.hasFailure === 'function'
        ? req.runtime.hasFailure()
        : false;

    if (!alreadyRegistered) {
      req.runtime.registerFailure(
        error,
        classifyFailure(error)
      );
    }

    if (req.runtime.getState() !== EXECUTION_STATES.COMPLETED) {
      req.runtime.complete();
    }

    const finalSnap = req.runtime.snapshot();

    logger.error({
      event: EVENTS.RUNTIME_FAILURE_HANDLED,
      request_id: finalSnap.identity.requestId,
      execution_id: finalSnap.identity.executionId,
      operation_id:
        finalSnap.operation?.identity?.id || null,
      state: finalSnap.state,
      failure_type:
        finalSnap.failure.classification?.type || 'unknown',
      recoverable:
        finalSnap.failure.classification?.recoverable || false,
      reliability_activated:
        finalSnap.reliability.activated,
      retries:
        finalSnap.reliability.retries,
      error_message:
        error.message
    });
  }

  if (res.headersSent) {
    return next(error);
  }

  const statusCode = getStatusCode(error);

  return res.status(statusCode).json({
    error:
      statusCode === 504
        ? 'Runtime operation timed out.'
        : 'Internal server error.',
    request_id:
      req.runtime?.getIdentity?.().requestId || null
  });
}

module.exports = runtimeFailureHandler;
