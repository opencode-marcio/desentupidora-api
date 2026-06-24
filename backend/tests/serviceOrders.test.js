const request = require('supertest');
const { app, initDb } = require('../src/app');
const sequelize = require('../src/database');
const { createTestUser, createTestOrder } = require('./helpers');

let server;
let token;
let secondToken;

beforeAll(async () => {
  await initDb();
  server = app.listen(0);
  const user = await createTestUser();
  token = user.token;
  const another = await createTestUser({ email: require('./helpers').uniqueEmail('outro') });
  secondToken = another.token;
});

afterAll(async () => {
  await sequelize.close();
  if (server) await new Promise(resolve => server.close(resolve));
});

describe('POST /api/orders', () => {
  it('deve criar uma nova ordem', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        clientName: 'Joao Cliente',
        clientAddress: 'Av Paulista, 1000',
        clientPhone: '11966666666',
        description: 'Entupimento severo',
      });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body.clientName).toBe('Joao Cliente');
    expect(res.body.status).toBe('pending');
    expect(res.body.userId).toBeDefined();
  });

  it('nao deve criar ordem sem nome do cliente', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({ clientAddress: 'Rua A' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('clientName');
  });

  it('nao deve criar ordem sem endereco', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({ clientName: 'Joao' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('clientAddress');
  });

  it('nao deve criar ordem sem autenticacao', async () => {
    const res = await request(app)
      .post('/api/orders')
      .send({ clientName: 'Joao', clientAddress: 'Rua A' });

    expect(res.status).toBe(401);
  });
});

describe('GET /api/orders', () => {
  it('deve listar ordens do usuario logado', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('orders');
    expect(res.body).toHaveProperty('total');
    expect(res.body).toHaveProperty('page');
    expect(res.body).toHaveProperty('totalPages');
    expect(Array.isArray(res.body.orders)).toBe(true);
  });

  it('nao deve retornar ordens de outros usuarios', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${secondToken}`);

    expect(res.status).toBe(200);
    expect(res.body.orders).toHaveLength(0);
  });

  it('deve suportar paginacao', async () => {
    const res = await request(app)
      .get('/api/orders?page=1&limit=10')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.page).toBe(1);
    expect(res.body.orders.length).toBeLessThanOrEqual(10);
  });
});

describe('GET /api/orders/:id', () => {
  let orderId;

  beforeAll(async () => {
    const order = await createTestOrder(token);
    orderId = order.id;
  });

  it('deve retornar detalhe da ordem', async () => {
    const res = await request(app)
      .get(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(orderId);
    expect(res.body.clientName).toBe('Cliente Teste');
  });

  it('nao deve retornar ordem de outro usuario', async () => {
    const res = await request(app)
      .get(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${secondToken}`);

    expect(res.status).toBe(403);
    expect(res.body.error).toContain('Acesso negado');
  });

  it('deve retornar 404 para ordem inexistente', async () => {
    const res = await request(app)
      .get('/api/orders/999999')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});

describe('PUT /api/orders/:id', () => {
  let orderId;

  beforeAll(async () => {
    const order = await createTestOrder(token);
    orderId = order.id;
  });

  it('deve atualizar dados da ordem', async () => {
    const res = await request(app)
      .put(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ clientName: 'Cliente Atualizado', description: 'Nova descricao' });

    expect(res.status).toBe(200);
    expect(res.body.clientName).toBe('Cliente Atualizado');
    expect(res.body.description).toBe('Nova descricao');
  });

  it('deve atualizar status para in_progress', async () => {
    const res = await request(app)
      .put(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'in_progress' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('in_progress');
  });

  it('deve definir completedAt ao concluir ordem', async () => {
    const res = await request(app)
      .put(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'completed' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('completed');
    expect(res.body.completedAt).toBeTruthy();
  });

  it('nao deve atualizar ordem de outro usuario', async () => {
    const res = await request(app)
      .put(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${secondToken}`)
      .send({ clientName: 'Hack' });

    expect(res.status).toBe(403);
  });
});

describe('DELETE /api/orders/:id', () => {
  let orderId;

  beforeAll(async () => {
    const order = await createTestOrder(token);
    orderId = order.id;
  });

  it('deve remover ordem', async () => {
    const res = await request(app)
      .delete(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toContain('removida');
  });

  it('deve retornar 404 ao buscar ordem removida', async () => {
    const res = await request(app)
      .get(`/api/orders/${orderId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});
