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
};

module.exports = EVENTS;