const { DataTypes } = require('sequelize');
const sequelize = require('../database');

const ServiceOrder = sequelize.define('ServiceOrder', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  clientName: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  clientAddress: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  clientPhone: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  status: {
    type: DataTypes.ENUM('pending', 'in_progress', 'completed', 'cancelled'),
    defaultValue: 'pending',
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  serviceCategory: {
    type: DataTypes.ENUM('preventive', 'corrective', 'budget'),
    allowNull: true,
  },
  preExistingDamage: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  recommendations: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  clientSignature: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  userId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  completedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
  shareToken: {
    type: DataTypes.STRING,
    allowNull: true,
  },
}, {
  tableName: 'service_orders',
});

module.exports = ServiceOrder;
