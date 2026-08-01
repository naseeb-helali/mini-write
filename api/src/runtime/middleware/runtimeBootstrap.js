const { createExecutionContext, EXECUTION_STATES } = require('../context/executionContext');
const logger = require('../../observability/logger');
const EVENTS = require('../../observability/events');

function runtimeBootstrap(req, res, next) {

const executionContext = createExecutionContext();

executionContext.initialize();

executionContext.attachMetadata({

  method: req.method,

  path: req.path,

  originalUrl: req.originalUrl,

  protocol: req.protocol,

  hostname: req.hostname,

  ip: req.ip

});

res.setHeader(

  'X-Request-Id',

  executionContext
    .getIdentity()
    .requestId

);

req.runtime = executionContext;
req.context = executionContext;

req.runtimeIntegrity = Object.freeze({
  runtime: req.runtime,
  executionId:
    req.runtime.getIdentity().executionId,
  requestId:
    req.runtime.getIdentity().requestId

});

/*
|--------------------------------------------------------------------------
| Runtime Completion Observer
|--------------------------------------------------------------------------
*/

res.on('finish', () => {

  if ([
    EXECUTION_STATES.INITIALIZED,
    EXECUTION_STATES.ACTIVE
  ].includes(executionContext.getState())) {

    executionContext.complete();

    logger.info({
      event: EVENTS.RUNTIME_COMPLETED,
      request_id: executionContext.getIdentity().requestId,
      execution_id: executionContext.getIdentity().executionId,
      operation_id:
        executionContext.getOperation()?.identity?.id || null,
      state: executionContext.getState(),
      failure_occurred: executionContext.hasFailure(),
      reliability_activated:
        executionContext.isReliabilityActivated()
    });

  }

});

next();

}

module.exports = runtimeBootstrap;
