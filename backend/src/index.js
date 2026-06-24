require('dotenv').config();
const { app, initDb } = require('./app');

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await initDb();
    console.log('Banco de dados conectado');
    console.log('Modelos sincronizados');
    app.listen(PORT, () => {
      console.log(`API rodando em http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('Erro ao iniciar:', err.message);
    process.exit(1);
  }
}

start();
