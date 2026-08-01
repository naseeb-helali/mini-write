'use strict';

const validationEnabled =
  process.env.RUNTIME_VALIDATION_ENABLED === 'true';

function isValidationEnabled() {

  return validationEnabled;

}

function printRuntimeSnapshot(
  title,
  runtime,
  extra = {}
) {

  if (!isValidationEnabled()) {

    return;

  }

  const snapshot =
    runtime.snapshot();

  console.log('\n================================================');
  console.log(`🔍 Runtime Validation :: ${title}`);
  console.log('================================================');

  console.log(

    JSON.stringify(

      {

        identity:
          snapshot.identity,

        state:
          snapshot.state,

        operation:
          snapshot.operation
            ? snapshot.operation.identity
            : null,

        policy:
          snapshot.policy,

        reliability:
          snapshot.reliability,

        failure:
          snapshot.failure,

        timestamps:
          snapshot.timestamps,

        metadata:
          snapshot.metadata,

        extra

      },

      null,

      2

    )

  );

}

function printRuntimeTransition(
  from,
  to
) {

  if (!isValidationEnabled()) {

    return;

  }

  console.log('\n------------------------------------------------');
  console.log(
    `➡ Runtime Transition :: ${from} → ${to}`
  );
  console.log('------------------------------------------------');

}


function printRuntimeCompletion(
  runtime,
  result = null
) {

  if (!isValidationEnabled()) {

    return;

  }

  const snapshot =
    runtime.snapshot();

  console.log('\n================================================');
  console.log('🏁 Runtime Validation :: COMPLETION');
  console.log('================================================');

  console.log(

    JSON.stringify(

      {

        identity:
          snapshot.identity,

        finalState:
          snapshot.state,

        operation:
          snapshot.operation
            ? snapshot.operation.identity
            : null,

        reliability:
          snapshot.reliability,

        failure:
          snapshot.failure,

        timestamps:
          snapshot.timestamps,

        metadata:
          snapshot.metadata,

        result

      },

      null,

      2

    )

  );

}

module.exports = {

  printRuntimeSnapshot,

  printRuntimeTransition,

  printRuntimeCompletion

};