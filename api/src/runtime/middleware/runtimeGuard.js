const { hasRuntime, getRuntime } = require('../runtimeAccess');

function runtimeGuard(req, res, next) {

  /*
  |--------------------------------------------------------------------------
  | Runtime Presence
  |--------------------------------------------------------------------------
  */

  if (!hasRuntime(req)) {

    return next(
      new Error(
        'Runtime Contract Violation: Runtime is missing.'
      )
    );

  }

  const runtime = getRuntime(req);

  /*
  |--------------------------------------------------------------------------
  | Runtime State Validation
  |--------------------------------------------------------------------------
  */

  if (runtime.getState() !== 'initialized') {

    return next(
      new Error(
        `Runtime Contract Violation: Invalid runtime state (${runtime.getState()}).`
      )
    );
}

/*
|--------------------------------------------------------------------------
| Runtime Integrity Verification
|--------------------------------------------------------------------------
*/

if (!Object.is(runtime, req.runtimeIntegrity.runtime)) {

  return next(
    new Error(
      'Runtime Contract Violation: Runtime instance has changed.'
    )
  );

}

const identity = runtime.getIdentity();

if (

  identity.executionId !==
  req.runtimeIntegrity.executionId

) {

  return next(
    new Error(
      'Runtime Contract Violation: Execution identity mismatch.'
    )
  );

}

if (

  identity.requestId !==
  req.runtimeIntegrity.requestId

) {

  return next(
    new Error(
      'Runtime Contract Violation: Request identity mismatch.'
    )
  );

}

  next();

}

module.exports = runtimeGuard;