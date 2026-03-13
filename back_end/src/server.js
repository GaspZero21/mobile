"use strict";

require("dotenv").config();

const app = require("./app");
const { sequelize, seedRoles } = require("./models");

const PORT = parseInt(process.env.PORT, 10) || 5001;

const start = async () => {
  try {
    await sequelize.authenticate();
    console.log("[DB] MySQL connection established");

    // Sync models without dropping existing data
    await sequelize.sync({ alter: process.env.NODE_ENV === "development" });
    console.log("[DB] Models synced");

    await seedRoles();
    console.log("[DB] Roles seeded");

    app.listen(PORT, () => {
      console.log(`[Server] GaspZero API running on http://localhost:${PORT}`);
      console.log(`[Server] Environment: ${process.env.NODE_ENV}`);
    });
  } catch (err) {
    console.error("[Server] Failed to start:", err.message);
    process.exit(1);
  }
};

start();
