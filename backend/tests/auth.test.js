const request = require('supertest');
const { app, initDb } = require('../src/app');
const { User } = require('../src/models');
const sequelize = require('../src/database');

let server;
let token;
let userData;

beforeAll(async () => {
  await initDb();
  server = app.listen(0);
});

afterAll(async () => {
  await sequelize.close();
  if (server) await new Promise(resolve => server.close(resolve));
});

describe('POST /api/auth/register', () => {
  const newUser = {
    name: 'Teste User',
    email: 'teste@teste.com',
    password: '123456',
    company: 'Desentupidora Teste',
    phone: '11999999999',
  };

  it('deve registrar um novo usuario com sucesso', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(newUser);

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user).toHaveProperty('id');
    expect(res.body.user.name).toBe(newUser.name);
    expect(res.body.user.email).toBe(newUser.email);
    expect(res.body.user.company).toBe(newUser.company);
    expect(res.body.user.role).toBe('technician');
    token = res.body.token;
    userData = res.body.user;
  });

  it('nao deve registrar com email duplicado', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(newUser);

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Email ja cadastrado');
  });

  it('nao deve registrar sem nome', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'sem@nome.com', password: '123456' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('name');
  });

  it('nao deve registrar com email invalido', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Teste', email: 'invalido', password: '123456' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('email');
  });

  it('nao deve registrar com senha curta', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Teste', email: 'curta@teste.com', password: '123' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('password');
  });
});

describe('POST /api/auth/login', () => {
  it('deve fazer login com credenciais validas', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'teste@teste.com', password: '123456' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body.user.email).toBe('teste@teste.com');
    token = res.body.token;
  });

  it('nao deve fazer login com senha errada', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'teste@teste.com', password: 'senha_errada' });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('invalido');
  });

  it('nao deve fazer login com email inexistente', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nao@existe.com', password: '123456' });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('invalido');
  });

  it('nao deve fazer login sem email', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ password: '123456' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('email');
  });
});

describe('GET /api/auth/me', () => {
  it('deve retornar dados do usuario logado', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe('teste@teste.com');
    expect(res.body.user).not.toHaveProperty('password');
  });

  it('nao deve acessar sem token', async () => {
    const res = await request(app).get('/api/auth/me');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Token');
  });

  it('nao deve acessar com token invalido', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer token_invalido_aqui');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Token');
  });
});

describe('PUT /api/auth/me', () => {
  it('deve atualizar dados do usuario', async () => {
    const res = await request(app)
      .put('/api/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Nome Atualizado', company: 'Nova Empresa' });

    expect(res.status).toBe(200);
    expect(res.body.user.name).toBe('Nome Atualizado');
    expect(res.body.user.company).toBe('Nova Empresa');
  });

  it('nao deve atualizar com email ja existente', async () => {
    await User.create({
      name: 'Outro User',
      email: 'outro@teste.com',
      password: '123456',
    });

    const res = await request(app)
      .put('/api/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: 'outro@teste.com' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Email ja cadastrado');
  });
});
