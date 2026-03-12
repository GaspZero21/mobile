'use strict';

require('dotenv').config();

const { sequelize } = require('../models');

(async () => {
  try {
    await sequelize.authenticate();
    console.log('[DB] Connection established');

    await sequelize.sync({ force: false, alter: true });
    console.log('[DB] All models synced successfully');

    process.exit(0);
  } catch (err) {
    console.error('[DB] Sync failed:', err.message);
    process.exit(1);
  }
})();
