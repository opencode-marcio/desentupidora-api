const path = require('path');
const fs = require('fs');
const qrcode = require('qrcode');

let sock = null;
let currentQR = null;
let connectionStatus = 'disconnected';
let statusListeners = [];

const AUTH_DIR = path.resolve(process.env.UPLOAD_DIR || './uploads', 'wa_auth');

function ensureAuthDir() {
  if (!fs.existsSync(AUTH_DIR)) {
    fs.mkdirSync(AUTH_DIR, { recursive: true });
  }
}

function onStatusChange(cb) {
  statusListeners.push(cb);
  return () => {
    statusListeners = statusListeners.filter(l => l !== cb);
  };
}

function notifyListeners() {
  const status = { status: connectionStatus, hasQR: !!currentQR, qr: currentQR };
  statusListeners.forEach(cb => cb(status));
}

async function getQRCode() {
  return currentQR;
}

function getStatus() {
  return { status: connectionStatus, hasQR: !!currentQR };
}

async function start() {
  if (sock) {
    try { await sock.logout(); } catch (_) {}
    sock = null;
  }

  const baileys = await import('@whiskeysockets/baileys');
  const { Boom } = await import('@hapi/boom');
  const { default: pino } = await import('pino');

  ensureAuthDir();
  const { state, saveCreds } = await baileys.useMultiFileAuthState(AUTH_DIR);

  connectionStatus = 'connecting';
  currentQR = null;
  notifyListeners();

  sock = baileys.makeWASocket({
    auth: state,
    printQRInTerminal: false,
    logger: pino({ level: 'silent' }),
    browser: ['DesentupidoraApp', 'Chrome', '1.0'],
    syncFullHistory: false,
  });

  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      try {
        currentQR = await qrcode.toDataURL(qr);
      } catch (_) {
        currentQR = qr;
      }
      connectionStatus = 'awaiting_scan';
      notifyListeners();
    }

    if (connection) {
      if (connection === 'open') {
        connectionStatus = 'connected';
        currentQR = null;
        notifyListeners();
      } else if (connection === 'close') {
        const shouldReconnect = (lastDisconnect?.error instanceof Boom)
          ? lastDisconnect.error.output.statusCode !== baileys.DisconnectReason.loggedOut
          : true;

        connectionStatus = 'disconnected';
        currentQR = null;
        notifyListeners();

        if (shouldReconnect) {
          setTimeout(() => start(), 5000);
        }
      }
    }
  });

  sock.ev.on('creds.update', saveCreds);
}

async function logout() {
  if (sock) {
    try { await sock.logout(); } catch (_) {}
    sock = null;
  }
  connectionStatus = 'disconnected';
  currentQR = null;
  const authDir = AUTH_DIR;
  if (fs.existsSync(authDir)) {
    const files = fs.readdirSync(authDir);
    for (const f of files) {
      fs.rmSync(path.join(authDir, f), { force: true });
    }
  }
  notifyListeners();
}

async function sendPDF(phone, pdfBuffer, filename, message) {
  if (!sock || connectionStatus !== 'connected') {
    throw new Error('WhatsApp nao conectado. Escaneie o QR code primeiro.');
  }

  const formattedPhone = phone.replace(/\D/g, '');
  const jid = `55${formattedPhone}@s.whatsapp.net`;

  try {
    if (pdfBuffer) {
      await sock.sendMessage(jid, {
        document: pdfBuffer,
        mimetype: 'application/pdf',
        fileName: filename || 'relatorio.pdf',
        caption: message || 'Segue o relatorio do servico realizado.',
      });
    } else {
      await sock.sendMessage(jid, {
        text: message || 'Segue o relatorio do servico realizado.',
      });
    }
    return true;
  } catch (err) {
    throw new Error(`Erro ao enviar WhatsApp: ${err.message}`);
  }
}

module.exports = { start, logout, getStatus, getQRCode, sendPDF, onStatusChange };
