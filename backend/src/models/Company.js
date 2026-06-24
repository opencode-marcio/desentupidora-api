const { DataTypes } = require('sequelize');
const sequelize = require('../database');

const Company = sequelize.define('Company', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  cnpj: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  phone: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  logo: {
    type: DataTypes.STRING,
    allowNull: true,
  },
}, {
  tableName: 'companies',
});

module.exports = Company;
