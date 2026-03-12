'use strict';

const { UniqueConstraintError, ValidationError } = require('sequelize');

// 404 handler — place before the global error handler
const notFound = (req, res, _next) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` });
};

// Global error handler
const errorHandler = (err, req, res, _next) => {
  const isDev = process.env.NODE_ENV === 'development';

  // Sequelize duplicate entry
  if (err instanceof UniqueConstraintError) {
    return res.status(409).json({ success: false, message: 'A record with that value already exists' });
  }

  // Sequelize validation errors
  if (err instanceof ValidationError) {
    return res.status(422).json({
      success: false,
      message: 'Validation error',
      errors: err.errors.map((e) => ({ field: e.path, message: e.message })),
    });
  }

  const status = err.status || err.statusCode || 500;
  const message = status < 500 ? err.message : 'Internal server error';

  res.status(status).json({
    success: false,
    message,
    ...(isDev && status === 500 && { stack: err.stack }),
  });
};

module.exports = { notFound, errorHandler };
