'use strict';

const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const UserRole = sequelize.define(
  'UserRole',
  {
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      primaryKey: true,
    },
    roleId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      primaryKey: true,
    },
  },
  {
    tableName: 'user_roles',
    timestamps: false,
  }
);

module.exports = UserRole;
