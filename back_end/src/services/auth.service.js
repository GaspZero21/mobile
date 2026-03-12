'use strict';

const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { User, Role, PasswordResetToken } = require('../models');
const tokenService = require('./token.service');
const emailService = require('./email.service');

const SALT_ROUNDS = parseInt(process.env.BCRYPT_SALT_ROUNDS, 10) || 12;

const ROLES_INCLUDE = { model: Role, as: 'roles', attributes: ['name'], through: { attributes: [] } };

function buildPayload(user) {
  const roles = (user.roles || []).map((r) => r.name);
  return { sub: user.id, email: user.email, roles };
}

function sanitizeUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phoneNumber: user.phoneNumber ?? null,
    roles: (user.roles || []).map((r) => r.name),
    reputationScore: user.reputationScore,
    createdAt: user.createdAt,
  };
}

// Register — hash password, assign USER role, return tokens
async function register({ name, email, password, phoneNumber }) {
  const existing = await User.unscoped().findOne({ where: { email } });
  if (existing) throw Object.assign(new Error('Email already in use'), { status: 409 });

  const hashed = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await User.create({ name, email, password: hashed, phoneNumber: phoneNumber || null });

  const userRole = await Role.findOne({ where: { name: 'USER' } });
  await user.addRole(userRole);

  const userWithRoles = await User.findByPk(user.id, { include: [ROLES_INCLUDE] });

  const payload = buildPayload(userWithRoles);
  const accessToken = tokenService.signAccessToken(payload);
  const refreshToken = await tokenService.createRefreshToken(user.id);

  return { user: sanitizeUser(userWithRoles), accessToken, refreshToken };
}

// Login — validate credentials, return tokens
async function login({ email, password }) {
  const user = await User.scope('withPassword').findOne({ where: { email }, include: [ROLES_INCLUDE] });
  if (!user) throw Object.assign(new Error('Invalid email or password'), { status: 401 });

  const valid = await bcrypt.compare(password, user.password);
  if (!valid) throw Object.assign(new Error('Invalid email or password'), { status: 401 });

  const payload = buildPayload(user);
  const accessToken = tokenService.signAccessToken(payload);
  const refreshToken = await tokenService.createRefreshToken(user.id);

  return { user: sanitizeUser(user), accessToken, refreshToken };
}

// Refresh — rotate token (revoke old, issue new pair)
async function refresh(incomingToken) {
  const { decoded, stored } = await tokenService.verifyRefreshToken(incomingToken);
  stored.revoked = true;
  await stored.save();

  const user = await User.findByPk(decoded.sub, { include: [ROLES_INCLUDE] });
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });

  const payload = buildPayload(user);
  const accessToken = tokenService.signAccessToken(payload);
  const refreshToken = await tokenService.createRefreshToken(user.id);

  return { accessToken, refreshToken };
}

// Logout — revoke the provided refresh token
async function logout(token) {
  await tokenService.revokeRefreshToken(token);
}

// Forgot password — generate reset token and send email
async function forgotPassword(email) {
  const user = await User.unscoped().findOne({ where: { email } });

  // Silently return if email not found — prevents email enumeration
  if (!user) return;

  // Invalidate any existing unused tokens for this user
  await PasswordResetToken.update(
    { usedAt: new Date() },
    { where: { userId: user.id, usedAt: null } }
  );

  const rawToken = crypto.randomBytes(32).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  await PasswordResetToken.create({ userId: user.id, tokenHash, expiresAt });

  const resetUrl = `${process.env.CLIENT_URL || 'http://localhost:3000'}/reset-password?token=${rawToken}`;
  await emailService.sendPasswordReset(user.email, user.name, resetUrl);
}

// Reset password — verify token, update password, revoke all sessions
async function resetPassword(rawToken, newPassword) {
  const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

  const record = await PasswordResetToken.findOne({ where: { tokenHash, usedAt: null } });

  if (!record || record.expiresAt < new Date()) {
    throw Object.assign(new Error('Invalid or expired reset token'), { status: 400 });
  }

  const user = await User.unscoped().findByPk(record.userId);
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });

  const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);
  await user.update({ password: hashed });

  // Mark token as used
  await record.update({ usedAt: new Date() });

  // Revoke all refresh tokens — force re-login on all devices
  await tokenService.revokeAllUserTokens(user.id);
}

module.exports = { register, login, refresh, logout, forgotPassword, resetPassword };
