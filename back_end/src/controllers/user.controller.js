'use strict';

const userService = require('../services/user.service');

const getMe = async (req, res, next) => {
  try {
    const user = await userService.getUserProfile(req.user.sub);
    return res.status(200).json({ success: true, data: { user } });
  } catch (err) {
    next(err);
  }
};

const updateProfile = async (req, res, next) => {
  try {
    const { name, avatar, bio } = req.body;
    const user = await userService.updateProfile(req.user.sub, { name, avatar, bio });
    return res.status(200).json({ success: true, message: 'Profile updated', data: { user } });
  } catch (err) {
    next(err);
  }
};

const updatePreferences = async (req, res, next) => {
  try {
    const { preferred_categories, notification_radius_km, urgent_only } = req.body;
    const preferences = await userService.upsertPreferences(req.user.sub, {
      preferred_categories,
      notification_radius_km,
      urgent_only,
    });
    return res.status(200).json({ success: true, message: 'Preferences updated', data: { preferences } });
  } catch (err) {
    next(err);
  }
};

const getReputation = async (req, res, next) => {
  try {
    const reputation = await userService.getUserReputation(req.params.id);
    return res.status(200).json({ success: true, data: reputation });
  } catch (err) {
    next(err);
  }
};

module.exports = { getMe, updateProfile, updatePreferences, getReputation };
