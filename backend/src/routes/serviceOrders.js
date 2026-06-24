const express = require('express');
const { ServiceOrder, Photo } = require('../models');
const auth = require('../middleware/auth');
const validate = require('../middleware/validate');

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

router.delete('/:id', auth, async (req, res) => {
  const order = await ServiceOrder.findByPk(req.params.id);
  if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
  if (req.user.role !== 'admin' && order.userId !== req.user.id) {
    return res.status(403).json({ error: 'Acesso negado' });
  }
  await order.destroy();
  res.json({ message: 'Ordem removida' });
});

module.exports = router;
