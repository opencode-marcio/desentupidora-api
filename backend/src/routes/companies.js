const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { Company } = require('../models');
const auth = require('../middleware/auth');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.resolve(process.env.UPLOAD_DIR || './uploads', 'logos');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'logo_' + unique + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|webp/;
    const ext = allowed.test(path.extname(file.originalname).toLowerCase());
    const mime = allowed.test(file.mimetype);
    cb(null, ext && mime);
  },
});

router.post('/logo', auth, upload.single('logo'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Nenhum arquivo enviado' });

    const company = await Company.findByPk(req.user.companyId);
    if (!company) return res.status(404).json({ error: 'Empresa nao encontrada' });

    if (company.logo) {
      const oldPath = path.resolve(process.env.UPLOAD_DIR || './uploads', company.logo);
      if (fs.existsSync(oldPath)) fs.unlinkSync(oldPath);
    }

    const logoPath = 'logos/' + req.file.filename;
    company.logo = logoPath;
    await company.save();

    res.json({ logo: logoPath });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put('/', auth, async (req, res) => {
  try {
    const company = await Company.findByPk(req.user.companyId);
    if (!company) return res.status(404).json({ error: 'Empresa nao encontrada' });

    const { name, cnpj, phone } = req.body;
    if (name) company.name = name;
    if (cnpj) company.cnpj = cnpj;
    if (phone !== undefined) company.phone = phone;
    await company.save();

    res.json(company);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    if (!req.user.companyId) return res.json(null);
    const company = await Company.findByPk(req.user.companyId);
    res.json(company);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

module.exports = router;
