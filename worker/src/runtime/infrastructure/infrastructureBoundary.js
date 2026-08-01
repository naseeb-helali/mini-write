const logger = require('../../observability/logger');
const EVENTS = require('../../observability/events');

const {
  runtimeOperationsTotal,
  runtimeRetriesTotal,
  runtimeFailuresTotal,
  runtimeOperationDurationSeconds
} = require('../observability/reliabilityMetrics');

const {
  executeWithReliability
} = require('../reliability/retryExecutor');

const {
  classifyFailure
} = require('../reliability/failureClassifier');

function getOperationId(runtime) {

  return (
    runtime
      .getOperation()
      ?.identity
      ?.id || 'unknown'
  );

}

function buildRuntimeLogContext(

  runtime,

  dependency,

  extra = {}

) {

  return {

    request_id:
      runtime
        .getIdentity()
        .requestId,

    execution_id:
      runtime
        .getIdentity()
        .executionId,

    operation_id:
      getOperationId(runtime),

    dependency,

    ...extra

  };

}

async function executeInfrastructureOperation({

  runtime,

  dependency,

  operation

}) {

  if (!runtime) {

    throw new Error(
      'Execution runtime is required.'
    );

  }

  if (!dependency) {

    throw new Error(
      'Infrastructure dependency is required.'
    );

  }

  if (typeof operation !== 'function') {

    throw new Error(
      'Infrastructure operation must be a function.'
    );

  }

  /*
  |--------------------------------------------------------------------------
  | Infrastructure Execution
  |--------------------------------------------------------------------------
  */

  const operationId =
    getOperationId(runtime);

  const durationTimer =
    runtimeOperationDurationSeconds.startTimer();

  logger.info({

    event:
      EVENTS.RUNTIME_OPERATION_STARTED,

    ...buildRuntimeLogContext(
      runtime,
      dependency
    )

  });

  try {

    const execution =
      await executeWithReliability({

        runtime,

        dependency,

        operation,

        onRetry({

          error,

          classification,

          attempt,

          nextAttempt

        }) {

          runtimeRetriesTotal.inc({

            operation:
              operationId,

            dependency,

            reason:
              classification.type

          });

          logger.warn({

            event:
              EVENTS.RUNTIME_OPERATION_RETRY,

            ...buildRuntimeLogContext(

              runtime,

              dependency,

              {

                failure_type:
                  classification.type,

                attempt,

                next_attempt:
                  nextAttempt,

                error_message:
                  error.message

              }

            )

          });

        }

      });

    const outcome =
      execution.recovered
        ? 'recovered'
        : 'success';

    runtimeOperationsTotal.inc({

      operation:
        operationId,

      dependency,

      outcome

    });

    durationTimer({

      operation:
        operationId,

      dependency,

      outcome

    });

    logger.info({

      event:
        EVENTS.RUNTIME_OPERATION_COMPLETED,

      ...buildRuntimeLogContext(

        runtime,

        dependency,

        {

          outcome,

          attempts:
            execution.attempts

        }

      )

    });

    return execution.result;

  } catch (error) {

    /*
    |--------------------------------------------------------------------------
    | Infrastructure Failure Classification
    |--------------------------------------------------------------------------
    */

    if (!runtime.hasFailure()) {

      runtime.registerFailure(

        error,

        classifyFailure(

          error,

          {

            dependency

          }

        )

      );

    }

    const failureSnapshot =
      runtime.getFailureSnapshot();

    const failureType =
      failureSnapshot
        .classification
        ?.type || 'unknown';

    const recoverable =
      failureSnapshot
        .classification
        ?.recoverable || false;

    runtimeFailuresTotal.inc({

      operation:
        operationId,

      dependency,

      failure_type:
        failureType,

      recoverable:
        String(recoverable)

    });

    runtimeOperationsTotal.inc({

      operation:
        operationId,

      dependency,

      outcome:
        'failure'

    });

    durationTimer({

      operation:
        operationId,

      dependency,

      outcome:
        'failure'

    });

    logger.error({

      event:
        EVENTS.RUNTIME_OPERATION_FAILED,

      ...buildRuntimeLogContext(

        runtime,

        dependency,

        {

          failure_type:
            failureType,

          recoverable,

          error_message:
            error.message,

          error_code:
            error.code || null

        }

      )

    });

    /*
    |--------------------------------------------------------------------------
    | Preserve Failure Propagation
    |--------------------------------------------------------------------------
    */

    throw error;

  }

}

module.exports = {

  executeInfrastructureOperation

};