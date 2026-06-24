const jwt = require('jsonwebtoken');
const { User } = require('../models');

async function auth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token nao fornecido' });
  }

  const token = header.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findByPk(decoded.id);
    if (!user) {
      return res.status(401).json({ error: 'Usuario nao encontrado' });
    }
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'Token invalido' });
  }
}

module.exports = auth;
