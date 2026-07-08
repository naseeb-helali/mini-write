const crypto = require('crypto');

function requestContext(req, res, next) {

  const requestId =
    `req_${crypto.randomBytes(8).toString('hex')}`;

  req.context = {
    requestId
  };

  res.setHeader(
    'X-Request-Id',
    requestId
  );

  next();
}

module.exports = requestContext;
