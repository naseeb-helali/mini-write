const FAILURE_TYPES = Object.freeze({

  TIMEOUT:
    'timeout',

  DEPENDENCY:
    'dependency',

  VALIDATION:
    'validation',

  AUTHENTICATION:
    'authentication',

  AUTHORIZATION:
    'authorization',

  INTERNAL:
    'internal'

});

const TRANSIENT_CODES = new Set([

  'ECONNRESET',

  'ECONNREFUSED',

  'EHOSTUNREACH',

  'ENETUNREACH',

  'EADDRNOTAVAIL',

  'ETIMEDOUT',

  'RUNTIME_TIMEOUT'

]);

function classifyFailure(

  error,

  context = {}

) {

  const statusCode =
    error?.statusCode ||
    error?.status;

  const code =
    error?.code;

  if (

    error?.name === 'RuntimeTimeoutError' ||

    code === 'RUNTIME_TIMEOUT'

  ) {

    return {

      type:
        FAILURE_TYPES.TIMEOUT,

      recoverable:
        true,

      retryable:
        true

    };

  }

  if (context.dependency) {

    return {

      type:
        FAILURE_TYPES.DEPENDENCY,

      recoverable:
        TRANSIENT_CODES.has(code),

      retryable:
        TRANSIENT_CODES.has(code)

    };

  }

  if (statusCode === 401) {

    return {

      type:
        FAILURE_TYPES.AUTHENTICATION,

      recoverable:
        false,

      retryable:
        false

    };

  }

  if (statusCode === 403) {

    return {

      type:
        FAILURE_TYPES.AUTHORIZATION,

      recoverable:
        false,

      retryable:
        false

    };

  }

  if (

    statusCode >= 400 &&

    statusCode < 500

  ) {

    return {

      type:
        FAILURE_TYPES.VALIDATION,

      recoverable:
        false,

      retryable:
        false

    };

  }

  return {

    type:
      FAILURE_TYPES.INTERNAL,

    recoverable:
      false,

    retryable:
      false

  };

}

module.exports = {

  FAILURE_TYPES,

  classifyFailure

};