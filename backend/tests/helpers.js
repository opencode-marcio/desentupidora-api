const request = require('supertest');
const { app } = require('../src/app');
const { User, ServiceOrder, Photo } = require('../src/models');
const path = require('path');
const fs = require('fs');

const TEST_UPLOAD_DIR = path.join(__dirname, '..', 'test-uploads');

function uniqueEmail(prefix = 'tecnico') {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}@teste.com`;
}

async function createTestUser(overrides = {}) {
  const userData = {
    name: 'Tecnico Teste',
    email: uniqueEmail(),
    password: '123456',
    company: 'Desentupidora Teste',
    phone: '11988888888',
    ...overrides,
  };

  const res = await request(app)
    .post('/api/auth/register')
    .send(userData);

  return {
    token: res.body.token,
    user: res.body.user,
    raw: userData,
  };
}

async function createTestOrder(token, overrides = {}) {
  const orderData = {
    clientName: 'Cliente Teste',
    clientAddress: 'Rua Teste, 123',
    clientPhone: '11977777777',
    description: 'Desentupimento de pia',
    ...overrides,
  };

  const res = await request(app)
    .post('/api/orders')
    .set('Authorization', `Bearer ${token}`)
    .send(orderData);

  return res.body;
}

async function cleanupDatabase() {
  await Photo.destroy({ where: {} });
  await ServiceOrder.destroy({ where: {} });
  await User.destroy({ where: {} });
}

function createTestImageBuffer() {
  const sharp = require('sharp');
  return sharp({
    create: {
      width: 100,
      height: 100,
      channels: 3,
      background: { r: 255, g: 0, b: 0 },
    },
  }).jpeg().toBuffer();
}

module.exports = {
  createTestUser,
  createTestOrder,
  cleanupDatabase,
  createTestImageBuffer,
  uniqueEmail,
  TEST_UPLOAD_DIR,
};
