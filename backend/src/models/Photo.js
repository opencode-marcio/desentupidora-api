const { DataTypes } = require('sequelize');
const sequelize = require('../database');

const Photo = sequelize.define('Photo', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  serviceOrderId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  filename: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  originalName: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  type: {
    type: DataTypes.ENUM('before', 'during', 'after'),
    allowNull: false,
  },
  latitude: {
    type: DataTypes.FLOAT,
    allowNull: true,
  },
  longitude: {
    type: DataTypes.FLOAT,
    allowNull: true,
  },
  annotations: {
    type: DataTypes.TEXT,
    allowNull: true,
    get() {
      const raw = this.getDataValue('annotations');
      return raw ? JSON.parse(raw) : null;
    },
    set(value) {
      this.setDataValue('annotations', JSON.stringify(value));
    },
  },
  takenAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'photos',
});

module.exports = Photo;
