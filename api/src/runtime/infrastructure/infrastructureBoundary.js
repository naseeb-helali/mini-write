const { getRuntime } = require('../runtimeAccess');
const logger = require('../../observability/logger');
const EVENTS = require('../../observability/events');
const {
    runtimeOperationsTotal,
    runtimeRetriesTotal,
    runtimeFailuresTotal,
    runtimeOperationDurationSeconds
} = require('../observability/reliabilityMetrics');
const { executeWithReliability } = require('../reliability/retryExecutor');
const { classifyFailure } = require('../reliability/failureClassifier');

function getOperationId(runtime) {
    return runtime.getOperation()?.identity?.id || 'unknown';
}

function buildRuntimeLogContext(req, runtime, dependency, extra = {}) {
    return {
        request_id: runtime.getIdentity().requestId,
        execution_id: runtime.getIdentity().executionId,
        operation_id: getOperationId(runtime),
        dependency,
        ...extra
    };
}


async function executeInfrastructureOperation({

    req,

    dependency,

    operation

}) {

    if (!req) {
        throw new Error(
            'Request object is required.'
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
    | Runtime Boundary
    |--------------------------------------------------------------------------
    */

    const runtime = getRuntime(req);

    /*
    |--------------------------------------------------------------------------
    | Infrastructure Execution
    |--------------------------------------------------------------------------
    */

    const operationId = getOperationId(runtime);
    const durationTimer = runtimeOperationDurationSeconds.startTimer();

    logger.info({
        event: EVENTS.RUNTIME_OPERATION_STARTED,
        ...buildRuntimeLogContext(req, runtime, dependency)
    });

    try {

        const execution = await executeWithReliability({
            runtime,
            dependency,
            operation,
            onRetry({ error, classification, attempt, nextAttempt }) {
                runtimeRetriesTotal.inc({
                    operation: operationId,
                    dependency,
                    reason: classification.type
                });

                logger.warn({
                    event: EVENTS.RUNTIME_OPERATION_RETRY,
                    ...buildRuntimeLogContext(req, runtime, dependency, {
                        failure_type: classification.type,
                        attempt,
                        next_attempt: nextAttempt,
                        error_message: error.message
                    })
                });
            }
        });

        const outcome = execution.recovered ? 'recovered' : 'success';

        runtimeOperationsTotal.inc({
            operation: operationId,
            dependency,
            outcome
        });

        durationTimer({
            operation: operationId,
            dependency,
            outcome
        });

        logger.info({
            event: EVENTS.RUNTIME_OPERATION_COMPLETED,
            ...buildRuntimeLogContext(req, runtime, dependency, {
                outcome,
                attempts: execution.attempts
            })
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
                classifyFailure(error, {
                    dependency
                })
            );
        }

        const failureSnapshot = runtime.getFailureSnapshot();
        const failureType =
            failureSnapshot.classification?.type || 'unknown';
        const recoverable =
            failureSnapshot.classification?.recoverable || false;

        runtimeFailuresTotal.inc({
            operation: operationId,
            dependency,
            failure_type: failureType,
            recoverable: String(recoverable)
        });

        runtimeOperationsTotal.inc({
            operation: operationId,
            dependency,
            outcome: 'failure'
        });

        durationTimer({
            operation: operationId,
            dependency,
            outcome: 'failure'
        });

        logger.error({
            event: EVENTS.RUNTIME_OPERATION_FAILED,
            ...buildRuntimeLogContext(req, runtime, dependency, {
                failure_type: failureType,
                recoverable,
                error_message: error.message,
                error_code: error.code || null
            })
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
