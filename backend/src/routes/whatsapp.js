const express = require('express');
const auth = require('../middleware/auth');
const wa = require('../whatsapp');

const router = express.Router();

router.get('/status', async (req, res) => {
  const status = wa.getStatus();
  res.json(status);
});

router.get('/qr', auth, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Apenas administradores podem ver o QR code' });
  }

  const qr = await wa.getQRCode();
  if (!qr) {
    const status = wa.getStatus();
    return res.json({ qr: null, status: status.status, message: status.status === 'connected' ? 'Ja conectado' : 'QR code nao disponivel' });
  }
  res.json({ qr, status: 'awaiting_scan' });
});

router.post('/start', auth, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Apenas administradores' });
  }
  await wa.start();
  res.json({ message: 'WhatsApp iniciado' });
});

router.post('/logout', auth, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Apenas administradores' });
  }
  await wa.logout();
  res.json({ message: 'WhatsApp desconectado' });
});

router.get('/status/stream', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  const sendStatus = (status) => {
    res.write(`data: ${JSON.stringify(status)}\n\n`);
  };

  sendStatus(wa.getStatus());

  const unsub = wa.onStatusChange(sendStatus);

  req.on('close', () => {
    unsub();
    res.end();
  });
});

module.exports = router;
