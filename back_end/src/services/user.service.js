'use strict';

const { User, Role, UserPreference } = require('../models');
const { getRank } = require('./reputation.service');

const ROLES_INCLUDE = {
  model: Role,
  as: 'roles',
  attributes: ['name'],
  through: { attributes: [] },
};

const PREFERENCES_INCLUDE = {
  model: UserPreference,
  as: 'preferences',
  attributes: ['preferredCategories', 'notificationRadiusKm', 'urgentOnly'],
};

async function getUserProfile(userId) {
  const user = await User.findByPk(userId, { include: [ROLES_INCLUDE, PREFERENCES_INCLUDE] });
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });
  return user;
}

async function updateProfile(userId, { name, avatar, bio }) {
  const user = await User.findByPk(userId);
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });

  const updates = {};
  if (name !== undefined) updates.name = name;
  if (avatar !== undefined) updates.avatar = avatar;
  if (bio !== undefined) updates.bio = bio;

  await user.update(updates);

  return User.findByPk(userId, { include: [ROLES_INCLUDE, PREFERENCES_INCLUDE] });
}

async function upsertPreferences(userId, { preferred_categories, notification_radius_km, urgent_only }) {
  const [prefs] = await UserPreference.findOrCreate({
    where: { userId },
    defaults: { userId },
  });

  const updates = {};
  if (preferred_categories !== undefined) updates.preferredCategories = preferred_categories;
  if (notification_radius_km !== undefined) updates.notificationRadiusKm = notification_radius_km;
  if (urgent_only !== undefined) updates.urgentOnly = urgent_only;

  await prefs.update(updates);
  return prefs.reload();
}

async function getUserReputation(userId) {
  const user = await User.findByPk(userId, { attributes: ['id', 'reputationScore'] });
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });

  return {
    userId: user.id,
    reputationScore: user.reputationScore,
    rank: getRank(user.reputationScore),
  };
}

module.exports = { getUserProfile, updateProfile, upsertPreferences, getUserReputation };
