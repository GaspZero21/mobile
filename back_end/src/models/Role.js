'use strict';

const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const ROLE_NAMES = ['USER', 'DONATOR', 'BENEFICIARY', 'FOOD_SAVER', 'ADMIN', 'COLLECTIVITE'];

const Role = sequelize.define(
  'Role',
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    name: {
      type: DataTypes.STRING(50),
      allowNull: false,
      unique: true,
    },
  },
  {
    tableName: 'roles',
    timestamps: false,
  }
);

Role.NAMES = ROLE_NAMES;

module.exports = Role;
