const OPERATIONS = Object.freeze({

  PROCESS_ID_CARD:
    'process_id_card',

  HEALTH_LIVENESS:
    'health_liveness',

  HEALTH_READINESS:
    'health_readiness'

});

const OPERATION_CATEGORIES = Object.freeze({

  BACKGROUND:
    'background',

  HEALTH:
    'health'

});

function attachQueryInterface(operation) {

  return Object.assign(operation, {

    isOperation(operationId) {

      return operation.identity.id === operationId;

    },

    isCategory(category) {

      return operation.category === category;

    },

    requiresDatabase() {

      return Boolean(
        operation.characteristics.requiresDatabase
      );

    },

    requiresStorage() {

      return Boolean(
        operation.characteristics.requiresStorage
      );

    },

    isAsynchronous() {

      return Boolean(
        operation.characteristics.asynchronous
      );

    },

    getSnapshot() {

      return Object.freeze({

        identity:
          operation.identity,

        category:
          operation.category,

        characteristics:
          operation.characteristics,

        metadata:
          operation.metadata

      });

    }

  });

}

function createOperationContext({

  id,

  category,

  characteristics = {},

  metadata = {}

}) {

  const operation = {

    identity: Object.freeze({

      id

    }),

    category,

    characteristics: Object.freeze({

      ...characteristics

    }),

    metadata: Object.freeze({

      ...metadata

    })

  };

  attachQueryInterface(operation);

  return Object.freeze(operation);

}

module.exports = {

  OPERATIONS,

  OPERATION_CATEGORIES,

  createOperationContext

};