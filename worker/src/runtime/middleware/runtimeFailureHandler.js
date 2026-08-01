const logger = require('../../observability/logger');
const EVENTS = require('../../observability/events');

const {
  EXECUTION_STATES
} = require('../context/executionContext');

const {
  classifyFailure
} = require('../reliability/failureClassifier');

function runtimeFailureHandler(runtime, error) {

  if (!runtime) {

    throw error;

  }

  const alreadyRegistered =

    typeof runtime.hasFailure === 'function'

      ? runtime.hasFailure()

      : false;

  if (!alreadyRegistered) {

    runtime.registerFailure(

      error,

      classifyFailure(error)

    );

  }

  if (

    runtime.getState() !==

    EXECUTION_STATES.COMPLETED

  ) {

    runtime.complete();

  }

  const finalSnapshot =

    runtime.snapshot();

  logger.error({

    event:
      EVENTS.RUNTIME_FAILURE_HANDLED,

    request_id:
      finalSnapshot.identity.requestId,

    execution_id:
      finalSnapshot.identity.executionId,

    operation_id:
      finalSnapshot.operation?.identity?.id || null,

    state:
      finalSnapshot.state,

    failure_type:
      finalSnapshot.failure.classification?.type || 'unknown',

    recoverable:
      finalSnapshot.failure.classification?.recoverable || false,

    reliability_activated:
      finalSnapshot.reliability.activated,

    retries:
      finalSnapshot.reliability.retries,

    error_message:
      error.message

  });

  throw error;

}

module.exports =
  runtimeFailureHandler;