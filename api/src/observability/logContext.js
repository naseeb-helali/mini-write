function buildRequestContext(req) {
  return {
    request_id:
      req?.context?.requestId || null
  };
}

function buildUserContext(req, userId) {
  return {
    request_id:
      req?.context?.requestId || null,

    user_id:
      userId || null
  };
}

function buildOperationContext(
  req,
  operationId,
  userId = null
) {
  return {
    request_id:
      req?.context?.requestId || null,

    operation_id:
      operationId || null,

    user_id:
      userId
  };
}

module.exports = {
  buildRequestContext,
  buildUserContext,
  buildOperationContext
};