function runtimeStateActivation(req, res, next) {

  const runtime = req.runtime;

  if (!runtime) {

    return next(
      new Error(
        'Runtime Contract Violation: Runtime is missing.'
      )
    );

  }

  if (!runtime.getPolicy()) {

    return next(
      new Error(
        'Runtime Contract Violation: Reliability policy is missing.'
      )
    );

  }

  runtime.activateReliability();

  if (!runtime.isReliabilityActivated()) {

    return next(
      new Error(
        'Runtime Contract Violation: Reliability activation failed.'
      )
    );

  }

  runtime.activate();

  next();

}

module.exports = runtimeStateActivation;