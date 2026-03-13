'use strict';

const { Router } = require('express');
const userController = require('../controllers/user.controller');
const { authenticateToken } = require('../middlewares/auth.middleware');
const { validateProfileUpdate, validatePreferencesUpdate } = require('../validators/user.validator');

const router = Router();

// GET /users/me — full profile with roles and preferences
router.get('/me', authenticateToken, userController.getMe);

// PUT /users/profile — update name, avatar, bio
router.put('/profile', authenticateToken, validateProfileUpdate, userController.updateProfile);

// PUT /users/preferences — upsert notification preferences
router.put('/preferences', authenticateToken, validatePreferencesUpdate, userController.updatePreferences);

// GET /users/:id/reputation — public reputation lookup
router.get('/:id/reputation', userController.getReputation);

module.exports = router;
