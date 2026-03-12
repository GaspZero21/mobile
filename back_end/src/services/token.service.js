'use strict';

const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const jwtConfig = require('../config/jwt');
const { RefreshToken } = require('../models');

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Parse a duration string like "7d", "15m", "1h" into milliseconds.
 */
function parseDurationMs(duration) {
  const unit = duration.slice(-1);
  const value = parseInt(duration.slice(0, -1), 10);
  const map = { s: 1000, m: 60 * 1000, h: 3600 * 1000, d: MS_PER_DAY };
  return (map[unit] || MS_PER_DAY * 7) * value;
}

/**
 * Sign and return a short-lived access token.
 */
function signAccessToken(payload) {
  return jwt.sign(payload, jwtConfig.access.secret, {
    expiresIn: jwtConfig.access.expiresIn,
    issuer: 'gaspzero',
    audience: 'gaspzero-client',
  });
}

/**
 * Sign a refresh token, persist it to DB, and return the raw token string.
 */
async function createRefreshToken(userId) {
  const token = jwt.sign({ sub: userId, jti: uuidv4() }, jwtConfig.refresh.secret, {
    expiresIn: jwtConfig.refresh.expiresIn,
    issuer: 'gaspzero',
    audience: 'gaspzero-client',
  });

  const expiresAt = new Date(Date.now() + parseDurationMs(jwtConfig.refresh.expiresIn));

  await RefreshToken.create({ token, userId, expiresAt });

  return token;
}

/**
 * Verify a refresh token string.
 * Throws if the token is invalid, expired, revoked, or not found in DB.
 */
async function verifyRefreshToken(token) {
  let decoded;
  try {
    decoded = jwt.verify(token, jwtConfig.refresh.secret, {
      issuer: 'gaspzero',
      audience: 'gaspzero-client',
    });
  } catch {
    throw Object.assign(new Error('Invalid or expired refresh token'), { status: 401 });
  }

  const stored = await RefreshToken.findOne({ where: { token } });

  if (!stored || stored.revoked || stored.expiresAt < new Date()) {
    throw Object.assign(new Error('Refresh token revoked or expired'), { status: 401 });
  }

  return { decoded, stored };
}

/**
 * Revoke a single refresh token (logout).
 */
async function revokeRefreshToken(token) {
  const stored = await RefreshToken.findOne({ where: { token } });
  if (stored) {
    stored.revoked = true;
    await stored.save();
  }
}

/**
 * Revoke all refresh tokens for a user (logout all devices).
 */
async function revokeAllUserTokens(userId) {
  await RefreshToken.update({ revoked: true }, { where: { userId, revoked: false } });
}

module.exports = {
  signAccessToken,
  createRefreshToken,
  verifyRefreshToken,
  revokeRefreshToken,
  revokeAllUserTokens,
};
