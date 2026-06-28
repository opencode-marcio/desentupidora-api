const express = require('express');
const { ServiceOrder, Photo, User } = require('../models');
const auth = require('../middleware/auth');
const validate = require('../middleware/validate');
const { generatePdf } = require('../pdfGenerator');
const wa = require('../whatsapp');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  const where = req.user.role === 'admin' ? {} : { userId: req.user.id };
  const page = parseInt(req.query.page) || 1;
  const limit = Math.min(parseInt(req.query.limit) || 50, 100);
  const offset = (page - 1) * limit;

  const { rows: orders, count: total } = await ServiceOrder.findAndCountAll({
    where,
    include: [Photo],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });
  res.json({ orders, total, page, totalPages: Math.ceil(total / limit) });
});

router.post('/', auth, validate({
  clientName: { required: true, minLength: 2 },
  clientAddress: { required: true, minLength: 3 },
}), async (req, res) => {
  try {
    const order = await ServiceOrder.create({
      ...req.body,
      userId: req.user.id,
    });
    res.status(201).json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/:id', auth, async (req, res) => {
  const order = await ServiceOrder.findByPk(req.params.id, {
    include: [Photo, 'User'],
  });
  if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
  if (req.user.role !== 'admin' && order.userId !== req.user.id) {
    return res.status(403).json({ error: 'Acesso negado' });
  }
  res.json(order);
});

router.put('/:id', auth, async (req, res) => {
  const order = await ServiceOrder.findByPk(req.params.id);
  if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
  if (req.user.role !== 'admin' && order.userId !== req.user.id) {
    return res.status(403).json({ error: 'Acesso negado' });
  }
  if (req.body.status === 'completed') {
    req.body.completedAt = new Date();
  }
  await order.update(req.body);
  res.json(order);
});

router.post('/:id/complete', auth, async (req, res) => {
  try {
    const order = await ServiceOrder.findByPk(req.params.id);
    if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(403).json({ error: 'Acesso negado' });
    }
    if (order.status === 'completed') {
      return res.status(400).json({ error: 'Ordem ja concluida' });
    }

    order.status = 'completed';
    order.completedAt = new Date();
    if (req.body.clientSignature) {
      order.clientSignature = req.body.clientSignature;
    }
    await order.save();

    res.json({ message: 'Ordem concluida com sucesso' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/:id/generate-and-send', auth, async (req, res) => {
  try {
    const order = await ServiceOrder.findByPk(req.params.id, {
      include: [
        { model: Photo },
        { model: User, attributes: ['name', 'company', 'companyId'] },
      ],
    });
    if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(403).json({ error: 'Acesso negado' });
    }
    if (order.status !== 'completed') {
      return res.status(400).json({ error: 'Conclua a ordem primeiro' });
    }

    const pdfBuffer = await generatePdf(order);
    const clientPhone = order.clientPhone;
    let sendMethod = 'nenhum';

    if (clientPhone) {
      const waStatus = wa.getStatus();

      if (waStatus.status === 'connected') {
        try {
          await wa.sendPDF(
            clientPhone,
            pdfBuffer,
            `relatorio-${order.id}.pdf`,
            `Ola! Segue o relatorio do servico realizado.\nCliente: ${order.clientName}\nProtocolo: #${order.id}`
          );
          sendMethod = 'whatsapp_interno';
        } catch (waErr) {
          console.error('Erro WhatsApp interno:', waErr.message);
          sendMethod = 'falha_whatsapp';
        }
      }

      const waWebhookUrl = process.env.WHATSAPP_WEBHOOK_URL;
      if (sendMethod !== 'whatsapp_interno' && waWebhookUrl) {
        try {
          const pdfBase64 = pdfBuffer.toString('base64');
          const payload = JSON.stringify({
            phone: clientPhone,
            message: 'Ola! Segue o relatorio do servico realizado.',
            pdfBase64,
            filename: `relatorio-${order.id}.pdf`,
            orderId: order.id,
            clientName: order.clientName,
          });

          const url = new URL(waWebhookUrl);
          const mod = url.protocol === 'https:' ? require('https') : require('http');
          await new Promise((resolve, reject) => {
            const reqWebhook = mod.request(waWebhookUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
                ...(process.env.WHATSAPP_API_KEY ? { 'Authorization': `Bearer ${process.env.WHATSAPP_API_KEY}` } : {}),
              },
            }, (resp) => {
              let body = '';
              resp.on('data', (c) => body += c);
              resp.on('end', () => resolve(body));
            });
            reqWebhook.on('error', (e) => {
              console.error('Erro webhook:', e.message);
              resolve(null);
            });
            reqWebhook.write(payload);
            reqWebhook.end();
          });
          sendMethod = sendMethod === 'falha_whatsapp' ? 'falha_whatsapp_webhook_ok' : 'webhook';
        } catch (whErr) {
          console.error('Erro webhook:', whErr.message);
        }
      }
    }

    const message = sendMethod === 'whatsapp_interno'
      ? 'Relatorio enviado com sucesso via WhatsApp'
      : sendMethod === 'webhook'
        ? 'Relatorio enviado com sucesso'
        : sendMethod === 'falha_whatsapp_webhook_ok'
          ? 'Relatorio enviado com sucesso (via webhook alternativo)'
          : clientPhone
            ? 'WhatsApp nao conectado - baixe o PDF e envie manualmente.'
            : 'Cliente sem telefone cadastrado.';

    res.json({ message, sendMethod });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete('/:id', auth, async (req, res) => {
  const order = await ServiceOrder.findByPk(req.params.id);
  if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
  if (req.user.role !== 'admin' && order.userId !== req.user.id) {
    return res.status(403).json({ error: 'Acesso negado' });
  }
  await order.destroy();
  res.json({ message: 'Ordem removida' });
});

router.post('/:id/complete-and-send', auth, async (req, res) => {
  try {
    const order = await ServiceOrder.findByPk(req.params.id, {
      include: [
        { model: Photo },
        { model: User, attributes: ['name', 'company', 'companyId'] },
      ],
    });
    if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(403).json({ error: 'Acesso negado' });
    }
    if (order.status === 'completed') {
      return res.status(400).json({ error: 'Ordem ja concluida' });
    }

    order.status = 'completed';
    order.completedAt = new Date();
    if (req.body.clientSignature) {
      order.clientSignature = req.body.clientSignature;
    }
    await order.save();

    const pdfBuffer = await generatePdf(order);
    const clientPhone = order.clientPhone;
    let sendMethod = 'nenhum';

    if (clientPhone) {
      const waStatus = wa.getStatus();

      if (waStatus.status === 'connected') {
        try {
          await wa.sendPDF(
            clientPhone,
            pdfBuffer,
            `relatorio-${order.id}.pdf`,
            `Ola! Segue o relatorio do servico realizado.\nCliente: ${order.clientName}\nProtocolo: #${order.id}`
          );
          sendMethod = 'whatsapp_interno';
        } catch (waErr) {
          console.error('Erro WhatsApp interno:', waErr.message);
          sendMethod = 'falha_whatsapp';
        }
      }

      const waWebhookUrl = process.env.WHATSAPP_WEBHOOK_URL;
      if (sendMethod !== 'whatsapp_interno' && waWebhookUrl) {
        try {
          const pdfBase64 = pdfBuffer.toString('base64');
          const payload = JSON.stringify({
            phone: clientPhone,
            message: 'Ola! Segue o relatorio do servico realizado.',
            pdfBase64,
            filename: `relatorio-${order.id}.pdf`,
            orderId: order.id,
            clientName: order.clientName,
          });

          const url = new URL(waWebhookUrl);
          const mod = url.protocol === 'https:' ? require('https') : require('http');
          await new Promise((resolve, reject) => {
            const reqWebhook = mod.request(waWebhookUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
                ...(process.env.WHATSAPP_API_KEY ? { 'Authorization': `Bearer ${process.env.WHATSAPP_API_KEY}` } : {}),
              },
            }, (resp) => {
              let body = '';
              resp.on('data', (c) => body += c);
              resp.on('end', () => resolve(body));
            });
            reqWebhook.on('error', (e) => {
              console.error('Erro webhook:', e.message);
              resolve(null);
            });
            reqWebhook.write(payload);
            reqWebhook.end();
          });
          sendMethod = sendMethod === 'falha_whatsapp' ? 'falha_whatsapp_webhook_ok' : 'webhook';
        } catch (whErr) {
          console.error('Erro webhook:', whErr.message);
        }
      }
    }

    const message = sendMethod === 'whatsapp_interno'
      ? 'Relatorio concluido e enviado com sucesso via WhatsApp'
      : sendMethod === 'webhook'
        ? 'Relatorio concluido e enviado com sucesso'
        : sendMethod === 'falha_whatsapp_webhook_ok'
          ? 'Relatorio concluido e enviado com sucesso (via webhook alternativo)'
          : clientPhone
            ? 'Relatorio concluido. WhatsApp nao conectado - baixe o PDF e envie manualmente.'
            : 'Relatorio concluido. Cliente sem telefone cadastrado.';

    res.json({ message, sendMethod });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
