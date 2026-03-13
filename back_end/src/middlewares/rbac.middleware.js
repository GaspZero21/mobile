'use strict';

/**
 * authorizeRoles(...roles)
 * Must be used AFTER authenticateToken.
 * Grants access only if req.user.roles contains at least one of the allowed roles.
 *
 * Usage:
 *   router.get('/admin', authenticateToken, authorizeRoles('ADMIN'), handler)
 *   router.get('/food', authenticateToken, authorizeRoles('ADMIN', 'FOOD_SAVER'), handler)
 */
const authorizeRoles = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Unauthenticated' });
    }

    const userRoles = req.user.roles || [];
    if (!roles.some((r) => userRoles.includes(r))) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required roles: ${roles.join(', ')}`,
      });
    }

    next();
  };
};

module.exports = { authorizeRoles };
