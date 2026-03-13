'use strict';

const { Router } = require('express');
const authController = require('../controllers/auth.controller');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { validateRegister, validateLogin, validateRefresh, validateForgotPassword, validateResetPassword } = require('../validators/auth.validator');

const router = Router();

// POST /auth/register
router.post('/register', validateRegister, authController.register);

// POST /auth/login
router.post('/login', validateLogin, authController.login);

// POST /auth/refresh
router.post('/refresh', validateRefresh, authController.refresh);

// POST /auth/logout  (requires valid access token)
router.post('/logout', authenticateToken, authController.logout);

// GET  /auth/me  — returns current user info from token
router.get('/me', authenticateToken, authController.me);

// POST /auth/forgot-password
router.post('/forgot-password', validateForgotPassword, authController.forgotPassword);

// POST /auth/reset-password
router.post('/reset-password', validateResetPassword, authController.resetPassword);

module.exports = router;
