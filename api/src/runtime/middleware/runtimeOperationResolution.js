const { createOperationContext } = require('../context/operationContext');
const { getRuntime } = require('../runtimeAccess');
const { resolveReliabilityPolicy } = require('../reliability/policyResolver');

function runtimeOperationResolution(operationDefinition) {

    if (!operationDefinition) {
        throw new Error(
            'Runtime operation definition is required.'
        );
    }

    const operation =
        createOperationContext(operationDefinition);

    return function (req, res, next) {

        const runtime =
            getRuntime(req);

        runtime.attachOperation(operation);

        const policy = resolveReliabilityPolicy(

            operation.identity.id

        );

        runtime.attachPolicy(policy);

        next();

    };

}

module.exports =
    runtimeOperationResolution;