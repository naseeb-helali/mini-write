function runtimeStateActivation(runtime) {

  if (!runtime) {

    throw new Error(
      'Runtime Contract Violation: Runtime is missing.'
    );

  }

  if (!runtime.getPolicy()) {

    throw new Error(
      'Runtime Contract Violation: Reliability policy is missing.'
    );

  }

  runtime.activateReliability();

  if (!runtime.isReliabilityActivated()) {

    throw new Error(
      'Runtime Contract Violation: Reliability activation failed.'
    );

  }

  runtime.activate();

  return runtime;

}

module.exports =
  runtimeStateActivation;