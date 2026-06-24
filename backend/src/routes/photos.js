const express = require('express');
const multer = require('multer');
const path = require('path');
const sharp = require('sharp');
const fs = require('fs');
const { Photo, ServiceOrder } = require('../models');
const auth = require('../middleware/auth');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = process.env.UPLOAD_DIR || './uploads';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, unique + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|webp/;
    const ext = allowed.test(path.extname(file.originalname).toLowerCase());
    const mime = allowed.test(file.mimetype);
    cb(null, ext && mime);
  },
});

const handleMulterError = (err, req, res, next) => {
  console.error('Multer error:', err.message);
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({ error: 'Arquivo muito grande (max 10MB)' });
  }
  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    return res.status(400).json({ error: 'Campo de arquivo inesperado' });
  }
  res.status(400).json({ error: err.message });
};

router.post('/upload/:serviceOrderId', auth, (req, res, next) => {
  upload.array('photos', 20)(req, res, (err) => {
    if (err) return handleMulterError(err, req, res, next);
    next();
  });
}, async (req, res) => {
  try {
    console.log(`Upload request: order=${req.params.serviceOrderId}, files=${req.files?.length || 0}`);
    const order = await ServiceOrder.findByPk(req.params.serviceOrderId);
    if (!order) return res.status(404).json({ error: 'Ordem nao encontrada' });
    if (req.user.role !== 'admin' && order.userId !== req.user.id) {
      return res.status(403).json({ error: 'Acesso negado' });
    }

    if (!req.files || req.files.length === 0) {
      console.error('No files in request. fields:', Object.keys(req.body), 'headers:', JSON.stringify({
        'content-type': req.headers['content-type']?.substring(0, 50),
        'content-length': req.headers['content-length'],
      }));
      return res.status(400).json({ error: 'Nenhuma foto enviada ou formato invalido' });
    }

    const { type, latitude, longitude, annotations, takenAt } = req.body;
    const results = [];

    for (const file of req.files) {
      const timestamp = takenAt ? new Date(takenAt) : new Date();
      const formattedDate = timestamp.toLocaleDateString('pt-BR');
      const formattedTime = timestamp.toLocaleTimeString('pt-BR');
      const lat = parseFloat(latitude) || 0;
      const lng = parseFloat(longitude) || 0;
      const gpsText = `${formattedDate} ${formattedTime} | ${lat.toFixed(6)}, ${lng.toFixed(6)}`;

      // Resize and get dimensions for watermark
      const outputPath = path.join(process.env.UPLOAD_DIR || './uploads', 'wm_' + file.filename);
      const resized = await sharp(file.path)
        .resize(1200, 900, { fit: 'inside' })
        .toBuffer({ resolveWithObject: true });
      const meta = resized.info;
      const w = meta.width;

      const svgOverlay = Buffer.from(
        `<svg width="${w}" height="50">
          <rect x="0" y="0" width="${w}" height="50" fill="rgba(0,0,0,0.6)" rx="5"/>
          <text x="10" y="32" font-family="Arial" font-size="18" fill="white">${gpsText}</text>
        </svg>`
      );

      await sharp(resized.data)
        .composite([{ input: svgOverlay, top: 10, left: 10 }])
        .toFile(outputPath);

      // Replace original with watermarked
      fs.unlinkSync(file.path);
      fs.renameSync(outputPath, file.path);

      const photo = await Photo.create({
        serviceOrderId: parseInt(req.params.serviceOrderId),
        filename: file.filename,
        originalName: file.originalname,
        type: type || 'during',
        latitude: parseFloat(latitude) || null,
        longitude: parseFloat(longitude) || null,
        annotations: annotations ? JSON.parse(annotations) : null,
        takenAt: timestamp,
      });

      results.push(photo);
    }

    res.status(201).json(results);
  } catch (err) {
    console.error(`Upload error for order ${req.params.serviceOrderId}:`, err.message, err.stack);
    res.status(400).json({ error: err.message });
  }
});

router.delete('/:id', auth, async (req, res) => {
  const photo = await Photo.findByPk(req.params.id, { include: [ServiceOrder] });
  if (!photo) return res.status(404).json({ error: 'Foto nao encontrada' });
  if (req.user.role !== 'admin' && photo.ServiceOrder.userId !== req.user.id) {
    return res.status(403).json({ error: 'Acesso negado' });
  }
  const filePath = path.join(process.env.UPLOAD_DIR || './uploads', photo.filename);
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  await photo.destroy();
  res.json({ message: 'Foto removida' });
});

module.exports = router;
