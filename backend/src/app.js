require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const sequelize = require('./database');
const authRoutes = require('./routes/auth');
const serviceOrderRoutes = require('./routes/serviceOrders');
const photoRoutes = require('./routes/photos');
const reportRoutes = require('./routes/reports');
const companyRoutes = require('./routes/companies');

const app = express();

app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
  next();
});
app.use('/uploads', express.static(process.env.UPLOAD_DIR || './uploads'));

app.use('/api/auth', authRoutes);
app.use('/api/orders', serviceOrderRoutes);
app.use('/api/photos', photoRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/companies', companyRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'desentupidora-api' });
});

app.get('/app.apk', (req, res) => {
  const apkPath = path.resolve(process.env.UPLOAD_DIR || './uploads', 'DesentupidoraApp.apk');
  if (!fs.existsSync(apkPath)) return res.status(404).send('APK nao encontrado');
  res.setHeader('Content-Type', 'application/vnd.android.package-archive');
  res.setHeader('Content-Disposition', 'attachment; filename="DesentupidoraApp.apk"');
  res.sendFile(apkPath);
});

app.get('/r/:token', async (req, res) => {
  try {
    const { ServiceOrder, Photo, User } = require('./models');
    const order = await ServiceOrder.findOne({
      where: { shareToken: req.params.token },
      include: [{ model: Photo }, { model: User, attributes: ['name', 'company'] }],
    });
    if (!order) return res.status(404).send('<h1>Link invalido</h1><p>Este relatorio nao existe ou foi removido.</p>');

    const uploadDir = process.env.UPLOAD_DIR || './uploads';
    const companyName = order.User?.company || 'Desentupidora';
    const statusMap = { pending: 'Pendente', in_progress: 'Em andamento', completed: 'Concluido', cancelled: 'Cancelado' };

    const photoHtml = (photos, label) => {
      if (!photos || photos.length === 0) return '';
      return `<h2 style="margin-top:30px">${label}</h2>
        <div style="display:flex;flex-wrap:wrap;gap:10px">
        ${photos.map(p => {
          const imgPath = path.join(uploadDir, p.filename);
          if (!fs.existsSync(imgPath)) return '';
          const imgData = fs.readFileSync(imgPath);
          const base64 = imgData.toString('base64');
          const ext = path.extname(p.filename).toLowerCase();
          const mime = ext === '.png' ? 'image/png' : 'image/jpeg';
          const dateStr = p.takenAt ? new Date(p.takenAt).toLocaleString('pt-BR') : '';
          return `<div style="flex:1;min-width:300px;max-width:500px">
            <img src="data:${mime};base64,${base64}" style="width:100%;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.15)">
            ${dateStr ? `<p style="text-align:center;font-size:12px;color:#666">${dateStr}</p>` : ''}
          </div>`;
        }).join('')}
        </div>`;
    };

    const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Relatorio - ${companyName}</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family: Arial, sans-serif; background: #f5f5f5; color: #333; padding: 20px; }
    .container { max-width: 800px; margin: 0 auto; background: #fff; border-radius: 12px; padding: 40px; box-shadow: 0 2px 12px rgba(0,0,0,0.1); }
    h1 { font-size: 24px; margin-bottom: 4px; }
    .subtitle { color: #666; font-size: 14px; margin-bottom: 20px; }
    hr { border: none; border-top: 1px solid #ddd; margin: 20px 0; }
    .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .info-label { font-size: 12px; color: #888; text-transform: uppercase; }
    .info-value { font-size: 16px; font-weight: 500; }
    .status-badge { display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 13px; font-weight: 600; }
    .status-completed { background: #d4edda; color: #155724; }
    .status-pending { background: #fff3cd; color: #856404; }
    .status-in_progress { background: #cce5ff; color: #004085; }
    .status-cancelled { background: #f8d7da; color: #721c24; }
    h2 { font-size: 18px; color: #444; border-left: 4px solid #007bff; padding-left: 12px; }
    img { max-width: 100%; }
    footer { margin-top: 30px; text-align: center; font-size: 12px; color: #999; }
  </style>
</head>
<body>
  <div class="container">
    <h1>${companyName}</h1>
    <p class="subtitle">Relatorio de Servico</p>
    <hr>
    <h2 style="border-color:#28a745">Dados do Servico</h2>
    <div class="info-grid" style="margin-top:12px">
      <div><div class="info-label">Cliente</div><div class="info-value">${order.clientName}</div></div>
      <div><div class="info-label">Endereco</div><div class="info-value">${order.clientAddress}</div></div>
      ${order.clientPhone ? `<div><div class="info-label">Telefone</div><div class="info-value">${order.clientPhone}</div></div>` : ''}
      <div><div class="info-label">Data</div><div class="info-value">${new Date(order.createdAt).toLocaleDateString('pt-BR')}</div></div>
      ${order.completedAt ? `<div><div class="info-label">Conclusao</div><div class="info-value">${new Date(order.completedAt).toLocaleDateString('pt-BR')}</div></div>` : ''}
      <div><div class="info-label">Tecnico</div><div class="info-value">${order.User?.name || 'N/A'}</div></div>
      <div><div class="info-label">Status</div><div><span class="status-badge status-${order.status}">${statusMap[order.status] || order.status}</span></div></div>
    </div>
    ${order.description ? `<p style="margin-top:12px"><strong>Descricao:</strong> ${order.description}</p>` : ''}
    ${photoHtml(order.Photos.filter(p => p.type === 'before'), 'ANTES')}
    ${photoHtml(order.Photos.filter(p => p.type === 'during'), 'DURANTE')}
    ${photoHtml(order.Photos.filter(p => p.type === 'after'), 'DEPOIS')}
    <hr>
    <footer>Relatorio gerado em ${new Date().toLocaleString('pt-BR')} | ${companyName}</footer>
  </div>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(html);
  } catch (err) {
    res.status(500).send('<h1>Erro</h1><p>Nao foi possivel carregar o relatorio.</p>');
  }
});

async function initDb(options = {}) {
  await sequelize.authenticate();
  await sequelize.sync(options);
}

module.exports = { app, initDb };
