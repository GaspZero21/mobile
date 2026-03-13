'use strict';

const { User } = require('../models');

const RANKS = [
  { min: 200, label: 'Food Hero' },
  { min: 100, label: 'Food Champion' },
  { min: 50,  label: 'Food Saver' },
  { min: 20,  label: 'Contributor' },
  { min: 0,   label: 'Newcomer' },
];

function getRank(score) {
  return RANKS.find((r) => score >= r.min).label;
}

async function increaseReputation(userId, points) {
  const user = await User.unscoped().findByPk(userId);
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });
  await user.increment('reputationScore', { by: points });
}

async function decreaseReputation(userId, points) {
  const user = await User.unscoped().findByPk(userId);
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });
  const newScore = Math.max(0, user.reputationScore - points);
  await user.update({ reputationScore: newScore });
}

module.exports = { getRank, increaseReputation, decreaseReputation };
