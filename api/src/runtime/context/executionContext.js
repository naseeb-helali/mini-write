const crypto = require('crypto');
const {createRuntimeMetadata} = require('../metadata/runtimeMetadata');

const EXECUTION_STATES = Object.freeze({
  CREATED: 'created',
  INITIALIZED: 'initialized',
  ACTIVE: 'active',
  COMPLETED: 'completed'
});

const ALLOWED_TRANSITIONS = Object.freeze({
  [EXECUTION_STATES.CREATED]: [
    EXECUTION_STATES.INITIALIZED
  ],

  [EXECUTION_STATES.INITIALIZED]: [
    EXECUTION_STATES.ACTIVE,
    EXECUTION_STATES.COMPLETED
  ],

  [EXECUTION_STATES.ACTIVE]: [
    EXECUTION_STATES.COMPLETED
  ],

  [EXECUTION_STATES.COMPLETED]: []
});

function generateId(prefix) {
  return `${prefix}_${crypto.randomBytes(8).toString('hex')}`;
}

function createExecutionContext() {

  const context = {

    identity: Object.freeze({

      requestId: generateId('req'),

      executionId: generateId('exec')

    }),

    // Temporary backward compatibility
    requestId: null,

    state: EXECUTION_STATES.CREATED,

    operation: null,

    policy: null,

    reliability: {
      activated: false,
      attempts: 0,
      retries: 0,
      lastFailureType: null,
      lastDependency: null,
      recovered: false
    },

    failure: {
      occurred: false,
      error: null,
      classification: null
    },

    user: {
      id: null
    },

    metadata: createRuntimeMetadata(),

    timestamps: {
      createdAt: new Date(),
      initializedAt: null,
      activatedAt: null,
      completedAt: null
    }

  };

  context.requestId =
    context.identity.requestId;

  attachLifecycle(context);

  attachRuntimeInterface(context);

  return context;

}

function validateOperationComponent(operation) {

  if (!operation) {
    throw new Error(
      'Operation component is required.'
    );
  }

  if (typeof operation !== 'object') {
    throw new Error(
      'Operation component must be an object.'
    );
  }

  if (
    !operation.identity ||
    typeof operation.identity.id !== 'string'
  ) {
    throw new Error(
      'Operation component must expose a valid identity.'
    );
  }

  if (
    typeof operation.isOperation !== 'function'
  ) {
    throw new Error(
      'Operation component must implement isOperation().'
    );
  }

  if (
    typeof operation.isCategory !== 'function'
  ) {
    throw new Error(
      'Operation component must implement isCategory().'
    );
  }

  if (
    typeof operation.getSnapshot !== 'function'
  ) {
    throw new Error(
      'Operation component must implement getSnapshot().'
    );
  }

}

function attachLifecycle(context) {

  function transition(nextState) {

    const allowed =
      ALLOWED_TRANSITIONS[context.state];

    if (!allowed.includes(nextState)) {

      throw new Error(
        `Illegal execution transition: ${context.state} -> ${nextState}`
      );

    }

    context.state = nextState;

    switch (nextState) {

      case EXECUTION_STATES.INITIALIZED:

        context.timestamps.initializedAt =
          new Date();

        break;

      case EXECUTION_STATES.ACTIVE:

        context.timestamps.activatedAt =
          new Date();

        break;

      case EXECUTION_STATES.COMPLETED:

        context.timestamps.completedAt =
          new Date();

        break;

    }

  }

  return Object.assign(context, {

    initialize() {

      transition(
        EXECUTION_STATES.INITIALIZED
      );
      return this;
    },

    activate() {

      transition(
        EXECUTION_STATES.ACTIVE
      );
      return this;
    },

    complete() {

      transition(
        EXECUTION_STATES.COMPLETED
      );
      return this;
    }

  });

}


function attachRuntimeInterface(context) {

  return Object.assign(context, {

    getIdentity() {
      return context.identity;
    },

    getState() {
      return context.state;
    },

    getOperation() {
      return context.operation;
    },

    getPolicy() {
      return context.policy;
    },

    shouldRetry() {
    return Boolean(
        context.policy?.retry
    );
    },

    getTimeout() {
        return context.policy?.timeout ?? null;
    },

    isRecoverable() {
        return Boolean(
            context.policy?.recoverable
        );
    },

    canRecover() {
    return (
        context.hasFailure() &&
        context.isRecoverable() &&
        Boolean(context.failure.classification?.recoverable)
    );
    },

    getRecoverySnapshot() {
    return Object.freeze({
        eligible: context.canRecover(),
        recoverable: context.isRecoverable(),
        retry: context.shouldRetry(),
        maxRetries: context.getMaxRetries()
    });
    },

    getMaxRetries() {
        return context.policy?.maxRetries ?? 0;
    },

    isReliabilityActivated() {
      return context.reliability.activated;
    },

    hasFailure() {
    return context.failure.occurred;
    },

    getFailure() {
        return context.failure.error;
    },

    registerFailure(error, classification = null) {
        if (context.failure.occurred) {
            return context;
        }
        context.failure.occurred = true;
        context.failure.error = error;
        context.failure.classification = classification;
        context.reliability.lastFailureType =
          classification?.type || null;
        return context;
    },

    registerReliabilityAttempt(dependency) {
      context.reliability.attempts += 1;
      context.reliability.lastDependency = dependency || null;
      return context;
    },

    registerRetry() {
      context.reliability.retries += 1;
      return context;
    },

    registerRecovery() {
      context.reliability.recovered = true;
      return context;
    },

    getFailureSnapshot() {

    return Object.freeze({

        occurred: context.failure.occurred,

        error: context.failure.error
            ? Object.freeze({
                message: context.failure.error.message,
                name: context.failure.error.name,
                code: context.failure.error.code || null
            })
            : null,

        classification:
          context.failure.classification

    });

    },

    getUser() {
      return context.user;
    },

    getMetadata() {
      return context.metadata;
    },

    attachOperation(operation) {

      validateOperationComponent(operation);

      if (
        context.state === EXECUTION_STATES.ACTIVE ||
        context.state === EXECUTION_STATES.COMPLETED
      ) {
        throw new Error(
          'Operation cannot be attached after execution has started.'
        );
      }

      if (context.operation !== null) {
        throw new Error(
          'Operation context already attached.'
        );
      }

      context.operation = operation;

      return this;

    },

    attachPolicy(policy) {

      if (!policy) {
        throw new Error(
          'Reliability policy is required.'
        );
      }

      if (context.policy) {
        throw new Error(
          'Reliability policy already attached.'
        );
      }

      context.policy = policy;

      return this;

    },

    activateReliability() {

      if (!context.policy) {
        throw new Error(
          'Reliability policy must be attached before activation.'
        );
      }

      if (context.reliability.activated) {
        return this;
      }

      context.reliability.activated = true;

      return this;

    },

    attachUser(user) {
      context.user = user;
      return this;
    },

    attachMetadata(metadata = {}) {
      context.metadata.enrich(metadata);
      return this;
    },

    snapshot() {

      return Object.freeze({

        identity:
          context.identity,

        state:
          context.state,

        operation:
          context.operation,
        
        policy:
          context.policy
            ? context.policy.identity
            : null,
        
        reliability: {
          activated:
            context.reliability.activated,
          attempts:
            context.reliability.attempts,
          retries:
            context.reliability.retries,
          lastFailureType:
            context.reliability.lastFailureType,
          lastDependency:
            context.reliability.lastDependency,
          recovered:
            context.reliability.recovered
        },

        failure: {
          occurred: context.failure.occurred,
          error:
              context.failure.error
                  ? {
                      message:
                          context.failure.error.message,
                      name:
                          context.failure.error.name,
                      code:
                          context.failure.error.code || null
                    }
                  : null,
          classification:
              context.failure.classification
      },

        recovery:
          context.getRecoverySnapshot(),

        user:
          context.user,

        metadata:
          context.metadata,

        timestamps:
          context.timestamps

      });

    }

  });

}


module.exports = {

  createExecutionContext,

  EXECUTION_STATES

};
