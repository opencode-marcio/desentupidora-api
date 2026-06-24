const User = require('./User');
const ServiceOrder = require('./ServiceOrder');
const Photo = require('./Photo');
const Company = require('./Company');

Company.hasMany(User, { foreignKey: 'companyId' });
User.belongsTo(Company, { foreignKey: 'companyId' });

User.hasMany(ServiceOrder, { foreignKey: 'userId' });
ServiceOrder.belongsTo(User, { foreignKey: 'userId' });

ServiceOrder.hasMany(Photo, { foreignKey: 'serviceOrderId' });
Photo.belongsTo(ServiceOrder, { foreignKey: 'serviceOrderId' });

module.exports = { User, ServiceOrder, Photo, Company };
