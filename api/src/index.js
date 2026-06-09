require('dotenv').config();
const express = require('express');
const { initUserTable } = require('./models/userModel');
const { initStorage } = require('./services/storageService');
const authRoutes = require('./routes/authRoutes');
const { getSystemHealth } = require('./health/healthService');
require('./config/redis');

const app = express();
app.use(express.json());

// 🔷 Routes & Health Probes (Defined outside for Testability)

// Liveness Probe (Light and fast)
app.get('/health/live', (req, res) => {
  res.status(200).json({
    status: "UP",
    message: "Service is alive"
  });
});

// Readiness Probe (Actual verification of services)
app.get('/health/ready', async (req, res) => {
  try {
    const health = await getSystemHealth();

    if (health.status === 'UP') {
      return res.status(200).json(health);
    } else {
      return res.status(503).json(health);
    }

  } catch (err) {
    return res.status(500).json({
      status: "DOWN",
      error: err.message
    });
  }
});

// Mounting API Routes 
app.use('/api/v1/auth', authRoutes);

// Bootstrapping function
async function startServer() {
  try {
    // 🔷 Database init 
    await initUserTable();
    console.log("[DB] Database migration completed.");

    // 🔷 Storage init
    await initStorage();
    console.log("[Storage] Object Storage is ready.");

    // 🔷 Start server
    const PORT = process.env.HTTP_PORT || 80;
    app.listen(PORT, () => {
      console.log(`[API] Server is listening on port ${PORT}`);
    });

  } catch (err) {
    console.error("Critical failure during server startup:", err);
    process.exit(1);
  }
}

module.exports = { app, startServer };

// Server will only run if the file is run directly (not via test).
if (require.main === module) {
  startServer();
}



