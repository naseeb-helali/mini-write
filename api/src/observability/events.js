const EVENTS = {

  /*
  |--------------------------------------------------------------------------
  | Request Lifecycle
  |--------------------------------------------------------------------------
  */

  REQUEST_STARTED:
    'request_started',

  REQUEST_COMPLETED:
    'request_completed',

  REQUEST_FAILED:
    'request_failed',

  /*
  |--------------------------------------------------------------------------
  | Authentication
  |--------------------------------------------------------------------------
  */

  USER_REGISTERED:
    'user_registered',

  USER_REGISTRATION_FAILED:
    'user_registration_failed',

  USER_LOGIN_SUCCESS:
    'user_login_success',

  USER_LOGIN_FAILED:
    'user_login_failed',

  /*
  |--------------------------------------------------------------------------
  | Upload Workflow
  |--------------------------------------------------------------------------
  */

  ID_UPLOAD_STARTED:
    'id_upload_started',

  ID_UPLOAD_SUCCESS:
    'id_upload_success',

  ID_UPLOAD_FAILED:
    'id_upload_failed',

  JOB_ENQUEUED:
    'job_enqueued',

  /*
  |--------------------------------------------------------------------------
  | Authorization
  |--------------------------------------------------------------------------
  */

  ACCESS_DENIED:
    'access_denied',

  INVALID_TOKEN:
    'invalid_token',

  /*
  |--------------------------------------------------------------------------
  | Internal Failures
  |--------------------------------------------------------------------------
  */

  DATABASE_ERROR:
    'database_error',

  STORAGE_ERROR:
    'storage_error',

  INTERNAL_ERROR:
    'internal_error'
  ,

  /*
  |--------------------------------------------------------------------------
  | Runtime Reliability
  |--------------------------------------------------------------------------
  */

  RUNTIME_OPERATION_STARTED:
    'runtime_operation_started',

  RUNTIME_OPERATION_COMPLETED:
    'runtime_operation_completed',

  RUNTIME_OPERATION_RETRY:
    'runtime_operation_retry',

  RUNTIME_OPERATION_FAILED:
    'runtime_operation_failed',

  RUNTIME_FAILURE_HANDLED:
    'runtime_failure_handled',

  RUNTIME_COMPLETED:
    'runtime_completed'
};

module.exports = EVENTS;
