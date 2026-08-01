const client = require('prom-client');

const registry = require('../../observability/registry');

const labels = [

  'operation',

  'dependency',

  'outcome'

];

const runtimeOperationsTotal = new client.Counter({

  name:
    'mw_worker_runtime_reliability_operations_total',

  help:
    'Total Worker runtime reliability boundary operations.',

  labelNames:
    labels,

  registers:
    [registry]

});

const runtimeRetriesTotal = new client.Counter({

  name:
    'mw_worker_runtime_reliability_retries_total',

  help:
    'Total Worker runtime reliability retries.',

  labelNames: [

    'operation',

    'dependency',

    'reason'

  ],

  registers:
    [registry]

});

const runtimeFailuresTotal = new client.Counter({

  name:
    'mw_worker_runtime_reliability_failures_total',

  help:
    'Total Worker runtime reliability failures.',

  labelNames: [

    'operation',

    'dependency',

    'failure_type',

    'recoverable'

  ],

  registers:
    [registry]

});

const runtimeOperationDurationSeconds =
  new client.Histogram({

    name:
      'mw_worker_runtime_reliability_operation_duration_seconds',

    help:
      'Worker runtime reliability boundary operation duration in seconds.',

    labelNames:
      labels,

    buckets: [

      0.01,

      0.025,

      0.05,

      0.1,

      0.25,

      0.5,

      1,

      2.5,

      5,

      10

    ],

    registers:
      [registry]

  });

module.exports = {

  runtimeOperationsTotal,

  runtimeRetriesTotal,

  runtimeFailuresTotal,

  runtimeOperationDurationSeconds

};