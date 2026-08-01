class RuntimeTimeoutError extends Error {

  constructor(message, metadata = {}) {

    super(message);

    this.name = 'RuntimeTimeoutError';

    this.code = 'RUNTIME_TIMEOUT';

    this.dependency =
      metadata.dependency || null;

    this.timeoutMs =
      metadata.timeoutMs || null;

    this.retryAttempt =
      metadata.retryAttempt || 0;

  }

}

module.exports = {

  RuntimeTimeoutError

};