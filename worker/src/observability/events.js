const EVENTS = {

  /*
  |--------------------------------------------------------------------------
  | Worker Lifecycle
  |--------------------------------------------------------------------------
  */

  WORKER_STARTED:
    'worker_started',

  WORKER_STOPPING:
    'worker_stopping',

  /*
  |--------------------------------------------------------------------------
  | Job Lifecycle
  |--------------------------------------------------------------------------
  */

  JOB_STARTED:
    'job_started',

  JOB_COMPLETED:
    'job_completed',

  JOB_FAILED:
    'job_failed',

  JOB_SKIPPED:
    'job_skipped',

  JOB_RETRY:
    'job_retry',

  /*
  |--------------------------------------------------------------------------
  | Image Processing
  |--------------------------------------------------------------------------
  */

  IMAGE_PROCESSING_STARTED:
    'image_processing_started',

  IMAGE_PROCESSING_COMPLETED:
    'image_processing_completed',

  /*
  |--------------------------------------------------------------------------
  | Storage Operations
  |--------------------------------------------------------------------------
  */

  STORAGE_DOWNLOAD_STARTED:
    'storage_download_started',

  STORAGE_DOWNLOAD_COMPLETED:
    'storage_download_completed',

  STORAGE_UPLOAD_STARTED:
    'storage_upload_started',

  STORAGE_UPLOAD_COMPLETED:
    'storage_upload_completed',

  STORAGE_OPERATION_FAILED:
    'storage_operation_failed',

  /*
  |--------------------------------------------------------------------------
  | Database Operations
  |--------------------------------------------------------------------------
  */

  DATABASE_UPDATE_STARTED:
    'database_update_started',

  DATABASE_UPDATE_COMPLETED:
    'database_update_completed',

  DATABASE_OPERATION_FAILED:
    'database_operation_failed',

  /*
  |--------------------------------------------------------------------------
  | Processing Decisions
  |--------------------------------------------------------------------------
  */

  RACE_CONDITION_AVOIDED:
    'race_condition_avoided',

  PROCESSING_ALREADY_COMPLETED:
    'processing_already_completed',

  /*
  |--------------------------------------------------------------------------
  | Internal Failures
  |--------------------------------------------------------------------------
  */

  INTERNAL_ERROR:
    'internal_error'
};

module.exports = EVENTS;