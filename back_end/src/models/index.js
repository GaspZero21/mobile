'use strict';

const sequelize = require('../config/database');
const User = require('./User');
const Role = require('./Role');
const UserRole = require('./UserRole');
const RefreshToken = require('./RefreshToken');
const UserPreference = require('./UserPreference');
const PasswordResetToken = require('./PasswordResetToken');

// ─── Associations ──────────────────────────────────────────
User.hasMany(RefreshToken, { foreignKey: 'userId', as: 'refreshTokens', onDelete: 'CASCADE' });
RefreshToken.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.belongsToMany(Role, { through: UserRole, foreignKey: 'userId', as: 'roles' });
Role.belongsToMany(User, { through: UserRole, foreignKey: 'roleId', as: 'users' });

User.hasOne(UserPreference, { foreignKey: 'userId', as: 'preferences', onDelete: 'CASCADE' });
UserPreference.belongsTo(User, { foreignKey: 'userId' });

User.hasMany(PasswordResetToken, { foreignKey: 'userId', as: 'passwordResetTokens', onDelete: 'CASCADE' });
PasswordResetToken.belongsTo(User, { foreignKey: 'userId' });

// ─── Seed default roles ────────────────────────────────────
async function seedRoles() {
  for (const name of Role.NAMES) {
    await Role.findOrCreate({ where: { name } });
  }
}

module.exports = { sequelize, User, Role, UserRole, RefreshToken, UserPreference, PasswordResetToken, seedRoles };
