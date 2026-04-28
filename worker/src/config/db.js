const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: process.env.DB_HOST || 'mw-postgres',
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: process.env.DB_PORT || 5432,
  // Production setting: close idle clients after 30 seconds
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Error handling for unexpected database connection loss
pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

module.exports = pool;
