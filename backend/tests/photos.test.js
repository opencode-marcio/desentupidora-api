const request = require('supertest');
const path = require('path');
const fs = require('fs');
const { app, initDb } = require('../src/app');
const sequelize = require('../src/database');
const { createTestUser, createTestOrder, createTestImageBuffer } = require('./helpers');

jest.setTimeout(20000);

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
});

afterAll(async () => {
  await sequelize.close();
  if (server) await new Promise(resolve => server.close(resolve));
});

describe('POST /api/photos/upload/:serviceOrderId', () => {
  it('deve fazer upload de fotos com sucesso', async () => {
    const imgBuffer = await createTestImageBuffer();

    const res = await request(app)
      .post(`/api/photos/upload/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .attach('photos', imgBuffer, 'test.jpg')
      .field('type', 'before')
      .field('latitude', '-23.561')
      .field('longitude', '-46.656')
      .field('takenAt', new Date().toISOString());

    expect(res.status).toBe(201);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(1);
    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0].type).toBe('before');
    expect(res.body[0].latitude).toBe(-23.561);
    expect(res.body[0].longitude).toBe(-46.656);
  });

  it('deve fazer upload de multiplas fotos', async () => {
    const imgBuffer = await createTestImageBuffer();

    const res = await request(app)
      .post(`/api/photos/upload/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .attach('photos', imgBuffer, 'foto1.jpg')
      .attach('photos', imgBuffer, 'foto2.jpg')
      .field('type', 'during');

    expect(res.status).toBe(201);
    expect(res.body).toHaveLength(2);
  });

  it('nao deve aceitar arquivo que nao seja imagem', async () => {
    const res = await request(app)
      .post(`/api/photos/upload/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .attach('photos', Buffer.from('nao é imagem'), 'arquivo.txt')
      .field('type', 'before');

    expect(res.status).toBe(400);
  });

  it('nao deve fazer upload sem autenticacao', async () => {
    const res = await request(app)
      .post(`/api/photos/upload/${orderId}`);

    expect(res.status).toBe(401);
  });

  it('nao deve fazer upload para ordem inexistente', async () => {
    const imgBuffer = await createTestImageBuffer();
    const res = await request(app)
      .post('/api/photos/upload/999999')
      .set('Authorization', `Bearer ${token}`)
      .attach('photos', imgBuffer, 'test.jpg')
      .field('type', 'after');

    expect(res.status).toBe(404);
  });

  it('nao deve fazer upload para ordem de outro usuario', async () => {
    const otherUser = await createTestUser({ email: require('./helpers').uniqueEmail('outro') });
    const imgBuffer = await createTestImageBuffer();

    const res = await request(app)
      .post(`/api/photos/upload/${orderId}`)
      .set('Authorization', `Bearer ${otherUser.token}`)
      .attach('photos', imgBuffer, 'test.jpg')
      .field('type', 'after');

    expect(res.status).toBe(403);
  });
});

describe('DELETE /api/photos/:id', () => {
  let photoId;

  beforeAll(async () => {
    const imgBuffer = await createTestImageBuffer();
    const res = await request(app)
      .post(`/api/photos/upload/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .attach('photos', imgBuffer, 'delete-test.jpg')
      .field('type', 'after');

    photoId = res.body[0].id;
  });

  it('deve remover foto', async () => {
    const res = await request(app)
      .delete(`/api/photos/${photoId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toContain('removida');
  });

  it('deve retornar 404 para foto inexistente', async () => {
    const res = await request(app)
      .delete('/api/photos/999999')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});
