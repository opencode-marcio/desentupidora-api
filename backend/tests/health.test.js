const request = require('supertest');
const { app, initDb } = require('../src/app');
const sequelize = require('../src/database');

let server;

beforeAll(async () => {
  await initDb();
  server = app.listen(0);
});

afterAll(async () => {
  await sequelize.close();
  if (server) await new Promise(resolve => server.close(resolve));
});

describe('GET /api/health', () => {
  it('deve retornar status ok', async () => {
    const res = await request(app).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.service).toBe('desentupidora-api');
  });
});
