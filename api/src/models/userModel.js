const pool = require('../config/db');

const initUserTable = async () => {
  const query = `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      password TEXT NOT NULL,
      identity_status VARCHAR(20) DEFAULT 'pending',
      document_url TEXT,
      id_card_url TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `;

  try {
    await pool.query(query);

    // Index for improving performance
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_users_identity_status
      ON users (identity_status);
    `);

    // Make sure to add the column if the table already exists and does not contain it.
    await pool.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS id_card_url TEXT;
    `);

    console.log("[DB] Users table is ready.");
  } catch (err) {
    console.error("[DB Error] Table initialization failed:", err);
    process.exit(1);
  }
};

module.exports = { initUserTable };
