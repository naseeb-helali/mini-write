const { Pool } = require('pg');

const pool = new Pool({
  user:
    process.env.POSTGRES_USER,

  host:
    process.env.POSTGRES_HOST,

  database:
    process.env.POSTGRES_DB,

  password:
    process.env.POSTGRES_PASSWORD,

  port:
    parseInt(
      process.env.POSTGRES_PORT,
      10
    ) || 5432,

  idleTimeoutMillis: 30000,

  connectionTimeoutMillis: 2000
});

pool.on(
  'error',
  (err) => {
    console.error(
      'Unexpected error on idle client',
      err
    );

    process.exit(-1);
  }
);

module.exports = pool;