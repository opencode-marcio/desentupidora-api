const express = require('express');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { ServiceOrder, Photo, User } = require('../models');
const auth = require('../middleware/auth');
const { generatePdf } = require('../pdfGenerator');

const router = express.Router();

const uploadDir = () => path.resolve(process.env.UPLOAD_DIR || './uploads');

router.get('/:serviceOrderId/pdf', auth, async (req, res) => {
  try {
    const order = await ServiceOrder.findByPk(req.params.serviceOrderId, {
      include: [
        { model: Photo },
        { model: User, attributes: ['name', 'company', 'companyId'] },
      ],
    });
    if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(403).json({ error: 'Acesso negado' });
    }

    const pdfBuffer = await generatePdf(order);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=relatorio-${order.id}.pdf`);
    res.send(pdfBuffer);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/:serviceOrderId/share', auth, async (req, res) => {
  try {
    const order = await ServiceOrder.findByPk(req.params.serviceOrderId);
    if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(403).json({ error: 'Acesso negado' });
    }

    if (!order.shareToken) {
      order.shareToken = crypto.randomUUID();
      await order.save();
    }

    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const link = `${baseUrl}/r/${order.shareToken}`;
    res.json({ link, token: order.shareToken });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
