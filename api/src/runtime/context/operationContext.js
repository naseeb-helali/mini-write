const OPERATIONS = Object.freeze({

  USER_LOGIN:
    'user_login',

  USER_REGISTER:
    'user_register',

  USER_PROFILE:
    'user_profile',

  ID_UPLOAD:
    'id_upload',

  HEALTH_LIVENESS:
    'health_liveness',

  HEALTH_READINESS:
    'health_readiness'

});

const OPERATION_CATEGORIES = Object.freeze({

  AUTH:
    'authentication',

  USER:
    'user',

  STORAGE:
    'storage',

  HEALTH:
    'health',

  BACKGROUND:
    'background'

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

    identity: {
      id
    },

    category,

    characteristics,

    metadata

  };

  attachQueryInterface(operation);

  return Object.freeze(operation);

}

module.exports = {

  OPERATIONS,

  OPERATION_CATEGORIES,

  createOperationContext

};
