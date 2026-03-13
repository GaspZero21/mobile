'use strict';

const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const ALLOWED_CATEGORIES = ['fruits', 'vegetables', 'bread', 'cooked_food', 'dairy', 'beverages', 'other'];

const UserPreference = sequelize.define(
  'UserPreference',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
      allowNull: false,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
    },
    preferredCategories: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: [],
    },
    notificationRadiusKm: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 2,
      validate: { min: 1, max: 100 },
    },
    urgentOnly: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
  },
  {
    tableName: 'user_preferences',
    timestamps: true,
  }
);

UserPreference.ALLOWED_CATEGORIES = ALLOWED_CATEGORIES;

module.exports = UserPreference;
