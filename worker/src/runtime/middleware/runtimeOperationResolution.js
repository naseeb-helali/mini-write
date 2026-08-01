const {
  createOperationContext
} = require('../context/operationContext');

const {
  resolveReliabilityPolicy
} = require('../reliability/policyResolver');

function runtimeOperationResolution(
  runtime,
  operationDefinition
) {

  if (!runtime) {
    throw new Error(
      'Execution runtime is required.'
    );
  }

  if (!operationDefinition) {
    throw new Error(
      'Runtime operation definition is required.'
    );
  }

  const operation =
    createOperationContext(
      operationDefinition
    );

  runtime.attachOperation(
    operation
  );

  const policy =
    resolveReliabilityPolicy(
      operation.identity.id
    );

  runtime.attachPolicy(
    policy
  );

  return runtime;

}

module.exports =
  runtimeOperationResolution;