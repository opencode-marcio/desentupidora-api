const { DataTypes } = require('sequelize');
const sequelize = require('../database');
const bcrypt = require('bcryptjs');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  role: {
    type: DataTypes.ENUM('admin', 'technician'),
    defaultValue: 'technician',
  },
  company: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  companyId: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  phone: {
    type: DataTypes.STRING,
    allowNull: true,
  },
}, {
  hooks: {
    beforeCreate: async (user) => {
      user.password = await bcrypt.hash(user.password, 10);
    },
  },
});

User.prototype.comparePassword = function (password) {
  return bcrypt.compare(password, this.password);
};

module.exports = User;
