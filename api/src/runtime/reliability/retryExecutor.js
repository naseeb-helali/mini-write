const { RuntimeTimeoutError } = require('./runtimeErrors');
const { classifyFailure } = require('./failureClassifier');

function wait(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function calculateBackoffMs(attempt) {
  return Math.min(100 * (2 ** Math.max(attempt - 1, 0)), 1000);
}

async function runWithTimeout(operation, timeoutMs, metadata) {
  if (!timeoutMs) {
    return operation();
  }

  let timeout;

  const timeoutPromise = new Promise((_, reject) => {
    timeout = setTimeout(() => {
      reject(
        new RuntimeTimeoutError(
          `Runtime operation timed out after ${timeoutMs}ms.`,
          metadata
        )
      );
    }, timeoutMs);
  });

  try {
    return await Promise.race([
      operation(),
      timeoutPromise
    ]);
  } finally {
    clearTimeout(timeout);
  }
}

async function executeWithReliability({
  runtime,
  dependency,
  operation,
  onRetry
}) {
  const policy = runtime.getPolicy();
  const maxRetries = runtime.shouldRetry()
    ? runtime.getMaxRetries()
    : 0;
  let attempt = 0;
  let lastError;
  let lastClassification;

  while (attempt <= maxRetries) {
    attempt += 1;
    runtime.registerReliabilityAttempt(dependency);

    try {
      const result = await runWithTimeout(
        () => operation({
          runtime,
          dependency,
          attempt
        }),
        policy?.timeout,
        {
          dependency,
          timeoutMs: policy?.timeout,
          retryAttempt: attempt
        }
      );

      if (attempt > 1) {
        runtime.registerRecovery();
      }

      return {
        result,
        attempts: attempt,
        recovered: attempt > 1
      };
    } catch (error) {
      lastError = error;
      lastClassification = classifyFailure(error, {
        dependency
      });

      const canRetry =
        attempt <= maxRetries &&
        runtime.isRecoverable() &&
        lastClassification.retryable;

      if (!canRetry) {
        break;
      }

      runtime.registerRetry();

      if (typeof onRetry === 'function') {
        onRetry({
          error,
          classification: lastClassification,
          attempt,
          nextAttempt: attempt + 1
        });
      }

      await wait(calculateBackoffMs(attempt));
    }
  }

  runtime.registerFailure(
    lastError,
    lastClassification
  );

  throw lastError;
}

module.exports = {
  executeWithReliability,
  calculateBackoffMs
};
