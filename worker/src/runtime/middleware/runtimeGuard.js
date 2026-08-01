function runtimeGuard(runtime, runtimeIntegrity) {

  /*
  |--------------------------------------------------------------------------
  | Runtime Presence
  |--------------------------------------------------------------------------
  */

  if (!runtime) {

    throw new Error(
      'Runtime Contract Violation: Runtime is missing.'
    );

  }

  if (!runtimeIntegrity) {

    throw new Error(
      'Runtime Contract Violation: Runtime integrity is missing.'
    );

  }

  /*
  |--------------------------------------------------------------------------
  | Runtime State Validation
  |--------------------------------------------------------------------------
  */

  if (runtime.getState() !== 'initialized') {

    throw new Error(
      `Runtime Contract Violation: Invalid runtime state (${runtime.getState()}).`
    );

  }

  /*
  |--------------------------------------------------------------------------
  | Runtime Integrity Verification
  |--------------------------------------------------------------------------
  */

  if (!Object.is(runtime, runtimeIntegrity.runtime)) {

    throw new Error(
      'Runtime Contract Violation: Runtime instance has changed.'
    );

  }

  const identity =
    runtime.getIdentity();

  if (

    identity.executionId !==
    runtimeIntegrity.executionId

  ) {

    throw new Error(
      'Runtime Contract Violation: Execution identity mismatch.'
    );

  }

  if (

    identity.requestId !==
    runtimeIntegrity.requestId

  ) {

    throw new Error(
      'Runtime Contract Violation: Request identity mismatch.'
    );

  }

  return runtime;

}

module.exports =
  runtimeGuard;