const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const pool = require('../config/db');

const businessMetrics = require('../observability/businessMetrics');
const logger = require('../observability/logger');
const EVENTS = require('../observability/events');
const {
    buildOperationContext
} = require('../observability/logContext');

async function login(req, res) {

    const { username, password } = req.body;

    try {

        const user = await pool.query(
            'SELECT * FROM users WHERE username = $1',
            [username]
        );

        if (user.rows.length === 0) {

            logger.warn({

                event: EVENTS.USER_LOGIN_FAILED,

                ...buildOperationContext(
                    req,
                    'login'
                ),

                username,

                reason: 'user_not_found'

            });

            return res.status(401).json({

                error: 'Invalid credentials'

            });

        }

        const validPass = await bcrypt.compare(

            password,

            user.rows[0].password

        );

        if (!validPass) {

            logger.warn({

                event: EVENTS.USER_LOGIN_FAILED,

                ...buildOperationContext(
                    req,
                    'login'
                ),

                username,

                reason: 'invalid_password'

            });

            return res.status(401).json({

                error: 'Invalid credentials'

            });

        }

        const token = jwt.sign(

            {

                id: user.rows[0].id,

                username: user.rows[0].username

            },

            process.env.JWT_SECRET,

            {

                expiresIn: process.env.JWT_EXPIRY

            }

        );

        businessMetrics.userLogins.inc();

        logger.info({

            event: EVENTS.USER_LOGIN_SUCCESS,

            ...buildOperationContext(

                req,

                'login',

                user.rows[0].id

            ),

            username

        });

        return res.json({

            token

        });

    }

    catch (err) {

        logger.error({

            event: EVENTS.USER_LOGIN_FAILED,

            ...buildOperationContext(

                req,

                'login'

            ),

            username,

            error_message: err.message

        });

        return res.status(500).json({

            error: 'Server error during login'

        });

    }

}

module.exports = {

    login

};