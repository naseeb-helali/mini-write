function attachQueryInterface(metadata) {

  Object.defineProperties(metadata, {

    has: {

      enumerable: false,

      value(key) {

        return Object.prototype.hasOwnProperty.call(
          metadata,
          key
        );

      }

    },

    get: {

      enumerable: false,

      value(key) {

        return metadata[key];

      }

    },

    keys: {

      enumerable: false,

      value() {

        return Object.keys(metadata);

      }

    },

    entries: {

      enumerable: false,

      value() {

        return Object.entries(metadata);

      }

    },

    getSnapshot: {

      enumerable: false,

      value() {

        return Object.freeze({

          ...metadata

        });

      }

    },

    enrich: {

      enumerable: false,

      value(values = {}) {

        for (const [key, value] of Object.entries(values)) {

          metadata[key] = value;

        }

        return this;

      }

    }

  });

}

function createRuntimeMetadata(initialMetadata = {}) {

  const metadata = {

    ...initialMetadata

  };

  attachQueryInterface(metadata);

  return metadata;

}

module.exports = {

  createRuntimeMetadata

};