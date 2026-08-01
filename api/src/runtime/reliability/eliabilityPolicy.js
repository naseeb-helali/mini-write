function createReliabilityPolicy({

  id,

  name,

  timeout = null,

  retry = false,

  maxRetries = 0,

  recoverable = false,

  metadata = {}

}) {

  if (!id) {
    throw new Error(
      'Reliability policy id is required.'
    );
  }

  if (!name) {
    throw new Error(
      'Reliability policy name is required.'
    );
  }

  const policy = {

    identity: Object.freeze({

      id,

      name

    }),

    timeout,

    retry,

    maxRetries,

    recoverable,

    metadata: {

      ...metadata

    }

  };

  return Object.freeze(policy);

}

module.exports = {

  createReliabilityPolicy

};