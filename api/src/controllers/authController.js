const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const storageService = require('../services/storageService');
const queueService = require('../services/queueService');

// 1. Register a new user
exports.register = async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: "Missing fields" });

  try {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = await pool.query(
      'INSERT INTO users (username, password) VALUES ($1, $2) RETURNING id, username',
      [username, hashedPassword]
    );
    res.status(201).json({ message: "User created", data: newUser.rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ error: "Username already exists" });
    res.status(500).json({ error: "Server error during registration" });
  }
};

// 2. Log in
exports.login = async (req, res) => {
  const { username, password } = req.body;
  try {
    const user = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    if (user.rows.length === 0) return res.status(401).json({ error: "Invalid credentials" });

    const validPass = await bcrypt.compare(password, user.rows[0].password);
    if (!validPass) return res.status(401).json({ error: "Invalid credentials" });

    const token = jwt.sign(
      { id: user.rows[0].id, username: user.rows[0].username },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRY }
    );
    res.json({ token });
  } catch (err) {
    res.status(500).json({ error: "Server error during login" });
  }
};

// 3. Get profile
exports.getProfile = (req, res) => {
  res.json({
    message: "Welcome to your secure profile",
    user: req.user
  });
};

// 4. Upload the identity and linking it to the database
exports.uploadID = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: "No file uploaded or invalid file type." });
        }

        // A. Upload the file to MinIO
        const uploadResult = await storageService.uploadIdCard(req.file);

	// b. Update the database with the new file link
	const userId = req.user.id;
        const updateQuery = "UPDATE users SET id_card_url = $1 WHERE id = $2 RETURNING id, username, id_card_url";
	const dbResult = await pool.query(updateQuery, [uploadResult.fileName, userId]);

	// C. tivate the bridge: Send the task to the background worker
	queueService.addIdCardJob(userId, uploadResult.fileName);

	// D. Respond to the user immediately
	res.status(200).json({
            message: "ID Card uploaded. Processing started in background!",
            user: dbResult.rows[0]
        });

    } catch (err) {
        console.error("Critical Failure in uploadID:", err);
        res.status(500).json({ error: "Internal server error during upload." });
    }
};
