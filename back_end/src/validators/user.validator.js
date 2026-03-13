'use strict';

const { body, validationResult } = require('express-validator');
const UserPreference = require('../models/UserPreference');

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array().map((e) => ({ field: e.path, message: e.msg })),
    });
  }
  next();
};

const updateProfileRules = [
  body('name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 }).withMessage('Name must be between 2 and 100 characters'),

  body('avatar')
    .optional({ nullable: true })
    .trim()
    .isURL().withMessage('Avatar must be a valid URL'),

  body('bio')
    .optional({ nullable: true })
    .trim()
    .isLength({ max: 500 }).withMessage('Bio cannot exceed 500 characters'),
];

const updatePreferencesRules = [
  body('preferred_categories')
    .optional()
    .isArray().withMessage('preferred_categories must be an array')
    .custom((arr) => {
      const invalid = arr.filter((item) => !UserPreference.ALLOWED_CATEGORIES.includes(item));
      if (invalid.length > 0) throw new Error(`Invalid categories: ${invalid.join(', ')}`);
      return true;
    }),

  body('notification_radius_km')
    .optional()
    .isInt({ min: 1, max: 100 }).withMessage('notification_radius_km must be an integer between 1 and 100'),

  body('urgent_only')
    .optional()
    .isBoolean().withMessage('urgent_only must be a boolean'),
];

module.exports = {
  validateProfileUpdate: [...updateProfileRules, handleValidationErrors],
  validatePreferencesUpdate: [...updatePreferencesRules, handleValidationErrors],
};
