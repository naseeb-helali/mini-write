const { createReliabilityPolicy } =
  require('./reliabilityPolicy');

const {
  OPERATIONS
} = require('../context/operationContext');

/*
|--------------------------------------------------------------------------
| Default Policy
|--------------------------------------------------------------------------
*/

const DEFAULT_POLICY = createReliabilityPolicy({

  id: 'default',

  name: 'Default Reliability Policy',

  timeout: 5000,

  retry: false,

  maxRetries: 0,

  recoverable: false

});

/*
|--------------------------------------------------------------------------
| Operation Policies
|--------------------------------------------------------------------------
*/

const POLICIES = Object.freeze({

  [OPERATIONS.USER_LOGIN]:

    createReliabilityPolicy({

      id: 'user-login',

      name: 'User Login Policy',

      timeout: 5000,

      retry: false,

      maxRetries: 0,

      recoverable: false

    }),

  [OPERATIONS.USER_REGISTER]:

    createReliabilityPolicy({

      id: 'user-register',

      name: 'User Registration Policy',

      timeout: 5000,

      retry: false,

      maxRetries: 0,

      recoverable: false

    }),

  [OPERATIONS.USER_PROFILE]:

    createReliabilityPolicy({

      id: 'user-profile',

      name: 'User Profile Policy',

      timeout: 3000,

      retry: false,

      maxRetries: 0,

      recoverable: false

    }),

  [OPERATIONS.ID_UPLOAD]:

    createReliabilityPolicy({

      id: 'id-upload',

      name: 'ID Upload Policy',

      timeout: 10000,

      retry: true,

      maxRetries: 2,

      recoverable: true

    }),

  [OPERATIONS.HEALTH_LIVENESS]:

    createReliabilityPolicy({

      id: 'health-live',

      name: 'Health Liveness Policy',

      timeout: 1000,

      retry: false,

      maxRetries: 0,

      recoverable: false

    }),

  [OPERATIONS.HEALTH_READINESS]:

    createReliabilityPolicy({

      id: 'health-ready',

      name: 'Health Readiness Policy',

      timeout: 3000,

      retry: false,

      maxRetries: 0,

      recoverable: false

    })

});

/*
|--------------------------------------------------------------------------
| Resolver
|--------------------------------------------------------------------------
*/

function resolveReliabilityPolicy(operationId) {

  if (!operationId) {
    return DEFAULT_POLICY;
  }

  return POLICIES[operationId] || DEFAULT_POLICY;

}

module.exports = {

  resolveReliabilityPolicy,

  DEFAULT_POLICY

};
