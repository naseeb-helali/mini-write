function getRuntime(runtime) {

  if (!runtime) {

    throw new Error(
      'Runtime has not been initialized.'
    );

  }

  return runtime;

}

function hasRuntime(runtime) {

  return Boolean(runtime);

}

module.exports = {

  getRuntime,

  hasRuntime

};