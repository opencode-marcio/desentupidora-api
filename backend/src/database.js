const { Sequelize } = require('sequelize');
const path = require('path');
require('dotenv').config();

let sequelize;

if (process.env.DATABASE_URL) {
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'postgres',
    logging: false,
    dialectOptions: {
      ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    },
    pool: {
      max: 10,
      min: 2,
      acquire: 30000,
      idle: 10000,
    },
  });
} else {
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: path.join(__dirname, '..', 'data', 'database.sqlite'),
    logging: false,
  });
}

module.exports = sequelize;
