const express = require('express');
const jwt = require('jsonwebtoken');
const { User, Company } = require('../models');
const auth = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = express.Router();

router.post('/register', validate({
  name: { required: true, minLength: 2 },
  email: { required: true, type: 'email' },
  password: { required: true, minLength: 6 },
}), async (req, res) => {
  try {
    const { name, email, password, company, phone } = req.body;
    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(400).json({ error: 'Email ja cadastrado' });
    }

    let companyId = null;
    if (company) {
      const [comp] = await Company.findOrCreate({
        where: { name: company },
        defaults: { name: company },
      });
      companyId = comp.id;
    }

    const user = await User.create({ name, email, password, company, companyId, phone });
    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ token, user: { id: user.id, name, email, role: user.role, company, companyId } });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/login', validate({
  email: { required: true, type: 'email' },
  password: { required: true },
}), async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ where: { email }, include: [Company] });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ error: 'Email ou senha invalidos' });
    }
    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, user: { id: user.id, name: user.name, email, role: user.role, company: user.company, companyId: user.companyId, Company: user.Company } });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/me', auth, async (req, res) => {
  const user = await User.findByPk(req.user.id, { include: [Company] });
  const { password, ...userData } = user.toJSON();
  res.json({ user: userData });
});

router.put('/me', auth, validate({
  name: { minLength: 2 },
  email: { type: 'email' },
}), async (req, res) => {
  try {
    const { name, email, company, phone } = req.body;
    if (email && email !== req.user.email) {
      const existing = await User.findOne({ where: { email } });
      if (existing) return res.status(400).json({ error: 'Email ja cadastrado' });
    }
    await req.user.update({ name, email, company, phone });
    const { password, ...userData } = req.user.toJSON();
    res.json({ user: userData });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
