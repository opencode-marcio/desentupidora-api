const request = require('supertest');
const { app, initDb } = require('../src/app');
const sequelize = require('../src/database');
const { createTestUser, createTestOrder, createTestImageBuffer } = require('./helpers');

let server;
let token;
let orderId;

beforeAll(async () => {
  await initDb();
  server = app.listen(0);
  const user = await createTestUser();
  token = user.token;
  const order = await createTestOrder(token);
  orderId = order.id;

  // Add a photo so the report has content
  const imgBuffer = await createTestImageBuffer();
  await request(app)
    .post(`/api/photos/upload/${orderId}`)
    .set('Authorization', `Bearer ${token}`)
    .attach('photos', imgBuffer, 'report-test.jpg')
    .field('type', 'before');
});

afterAll(async () => {
  await sequelize.close();
  if (server) await new Promise(resolve => server.close(resolve));
});

describe('GET /api/reports/:serviceOrderId/pdf', () => {
  it('deve gerar PDF da ordem', async () => {
    const res = await request(app)
      .get(`/api/reports/${orderId}/pdf`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('application/pdf');
    expect(res.headers['content-disposition']).toContain('relatorio');
    expect(res.body.length).toBeGreaterThan(0);
  });

  it('nao deve gerar PDF sem autenticacao', async () => {
    const res = await request(app)
      .get(`/api/reports/${orderId}/pdf`);

    expect(res.status).toBe(401);
  });

  it('nao deve gerar PDF para ordem inexistente', async () => {
    const res = await request(app)
      .get('/api/reports/999999/pdf')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('nao deve gerar PDF de ordem de outro usuario', async () => {
    const otherUser = await createTestUser({ email: require('./helpers').uniqueEmail('outro') });

    const res = await request(app)
      .get(`/api/reports/${orderId}/pdf`)
      .set('Authorization', `Bearer ${otherUser.token}`);

    expect(res.status).toBe(403);
  });
});

describe('POST /api/reports/:serviceOrderId/share', () => {
  it('deve gerar link compartilhavel', async () => {
    const res = await request(app)
      .post(`/api/reports/${orderId}/share`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('link');
    expect(res.body).toHaveProperty('token');
    expect(res.body.link).toContain('/r/');
  });

  it('deve retornar o mesmo token na segunda chamada', async () => {
    const res1 = await request(app)
      .post(`/api/reports/${orderId}/share`)
      .set('Authorization', `Bearer ${token}`);

    const res2 = await request(app)
      .post(`/api/reports/${orderId}/share`)
      .set('Authorization', `Bearer ${token}`);

    expect(res1.body.token).toBe(res2.body.token);
  });

  it('deve acessar relatorio via link compartilhavel', async () => {
    const share = await request(app)
      .post(`/api/reports/${orderId}/share`)
      .set('Authorization', `Bearer ${token}`);

    const res = await request(app)
      .get(`/r/${share.body.token}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.text).toContain('Relatorio');
    expect(res.text).toContain('Cliente Teste');
  });

  it('deve retornar 404 para token invalido', async () => {
    const res = await request(app)
      .get('/r/token-invalido-xyz');

    expect(res.status).toBe(404);
  });

  it('nao deve compartilhar ordem de outro usuario', async () => {
    const otherUser = await createTestUser({ email: require('./helpers').uniqueEmail('outro') });

    const res = await request(app)
      .post(`/api/reports/${orderId}/share`)
      .set('Authorization', `Bearer ${otherUser.token}`);

    expect(res.status).toBe(403);
  });
});
