function getRuntime(req) {

  if (!req) {
    throw new Error('Request object is required.');
  }

  if (!req.runtime) {
    throw new Error('Runtime has not been initialized.');
  }

  return req.runtime;

}

function hasRuntime(req) {

  return Boolean(req?.runtime);

}

module.exports = {

  getRuntime,

  hasRuntime

};