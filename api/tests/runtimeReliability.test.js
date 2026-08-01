const {
  createExecutionContext
} = require('../src/runtime/context/executionContext');
const {
  createOperationContext,
  OPERATIONS,
  OPERATION_CATEGORIES
} = require('../src/runtime/context/operationContext');
const {
  createReliabilityPolicy
} = require('../src/runtime/reliability/reliabilityPolicy');
const {
  executeInfrastructureOperation
} = require('../src/runtime/infrastructure/infrastructureBoundary');
const { DEPENDENCIES } = require('../src/runtime/infrastructure/dependencies');

function createActiveRuntime(policy) {
  const runtime = createExecutionContext();

  runtime.initialize();
  runtime.attachOperation(
    createOperationContext({
      id: OPERATIONS.ID_UPLOAD,
      category: OPERATION_CATEGORIES.STORAGE
    })
  );
  runtime.attachPolicy(policy);
  runtime.activateReliability();
  runtime.activate();

  return runtime;
}

describe('API Runtime Reliability Behaviour', () => {
  test('retries recoverable dependency failures and records recovery state', async () => {
    const runtime = createActiveRuntime(
      createReliabilityPolicy({
        id: 'test-retry',
        name: 'Test Retry Policy',
        timeout: 1000,
        retry: true,
        maxRetries: 2,
        recoverable: true
      })
    );
    const req = { runtime };
    let attempts = 0;

    const result = await executeInfrastructureOperation({
      req,
      dependency: DEPENDENCIES.REDIS,
      operation: async () => {
        attempts += 1;

        if (attempts < 3) {
          const error = new Error('Redis temporarily unavailable.');
          error.code = 'EADDRNOTAVAIL';
          throw error;
        }

        return { ok: true };
      }
    });

    const snapshot = runtime.snapshot();

    expect(result).toEqual({ ok: true });
    expect(attempts).toBe(3);
    expect(snapshot.reliability.retries).toBe(2);
    expect(snapshot.reliability.recovered).toBe(true);
    expect(snapshot.failure.occurred).toBe(false);
  });

  test('classifies timeout failures and records them in runtime context', async () => {
    const runtime = createActiveRuntime(
      createReliabilityPolicy({
        id: 'test-timeout',
        name: 'Test Timeout Policy',
        timeout: 5,
        retry: false,
        maxRetries: 0,
        recoverable: true
      })
    );
    const req = { runtime };

    await expect(
      executeInfrastructureOperation({
        req,
        dependency: DEPENDENCIES.POSTGRESQL,
        operation: async () => {
          await new Promise((resolve) => {
            setTimeout(resolve, 25);
          });
        }
      })
    ).rejects.toMatchObject({
      name: 'RuntimeTimeoutError',
      code: 'RUNTIME_TIMEOUT'
    });

    const snapshot = runtime.snapshot();

    expect(snapshot.failure.occurred).toBe(true);
    expect(snapshot.failure.classification.type).toBe('timeout');
    expect(snapshot.reliability.lastFailureType).toBe('timeout');
  });
});
