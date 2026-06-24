const express = require('express');
const PDFDocument = require('pdfkit');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { ServiceOrder, Photo, User, Company } = require('../models');
const auth = require('../middleware/auth');

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

    let company = null;
    if (order.User?.companyId) {
      company = await Company.findByPk(order.User.companyId);
    }

    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => {
      const pdfBuffer = Buffer.concat(chunks);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename=relatorio-${order.id}.pdf`);
      res.send(pdfBuffer);
    });

    const PAGE_W = 525;
    const MARGIN = 40;
    const MAX_Y = 760;
    const FOOTER_Y = 780;

    const companyName = company?.name || order.User?.company || 'Desentupidora';
    const categoryMap = { preventive: 'Preventiva', corrective: 'Corretiva', budget: 'Orcamento' };
    const statusMap = { pending: 'Pendente', in_progress: 'Em andamento', completed: 'Concluido', cancelled: 'Cancelado' };

    // ====================== PAGE 1 ======================
    // Logo + Company header
    if (company?.logo) {
      const logoPath = path.resolve(uploadDir(), company.logo);
      if (fs.existsSync(logoPath)) {
        doc.image(logoPath, MARGIN, 40, { width: 100, fit: [100, 60] });
      }
    }

    doc.fontSize(20).font('Helvetica-Bold').text(companyName, MARGIN, 40, { align: 'center' });
    if (company?.cnpj || company?.phone) {
      const compLine = [company.cnpj ? `CNPJ: ${company.cnpj}` : '', company.phone ? `Tel: ${company.phone}` : ''].filter(Boolean).join(' | ');
      doc.fontSize(9).font('Helvetica').text(compLine, { align: 'center' });
    }
    doc.moveDown(0.5);
    doc.fontSize(12).font('Helvetica').text('RELATORIO DE SERVICO', { align: 'center' });
    doc.moveDown(0.3);
    doc.moveTo(MARGIN, doc.y).lineTo(550, doc.y).stroke();
    doc.moveDown();

    // Client info
    const col1X = MARGIN;
    const col2X = 300;
    const lblW = 120;
    let y = doc.y;

    const fld = (label, value, x, yPos) => {
      doc.fontSize(9).font('Helvetica-Bold').text(label, x, yPos);
      doc.fontSize(10).font('Helvetica').text(value || '-', x + lblW, yPos, { width: 180 });
      return yPos + 16;
    };

    y = fld('Cliente:', order.clientName, col1X, y);
    y = fld('Endereco:', order.clientAddress, col1X, y);
    y = fld('Telefone:', order.clientPhone || '-', col1X, y);

    let y2 = fld('Data:', order.createdAt ? new Date(order.createdAt).toLocaleDateString('pt-BR') : '-', col2X, doc.y - 48);
    y2 = fld('Tecnico:', order.User?.name || 'N/A', col2X, y2);
    y2 = fld('Status:', statusMap[order.status] || order.status, col2X, y2);
    if (order.serviceCategory) y2 = fld('Categoria:', categoryMap[order.serviceCategory] || order.serviceCategory, col2X, y2);
    if (order.completedAt) y2 = fld('Conclusao:', new Date(order.completedAt).toLocaleString('pt-BR'), col2X, y2);

    doc.y = Math.max(y, y2) + 8;

    if (order.description) {
      doc.fontSize(10).font('Helvetica-Bold').text('Descricao:');
      doc.fontSize(10).font('Helvetica').text(order.description, { indent: 10 });
      doc.moveDown(0.3);
    }
    if (order.preExistingDamage) {
      doc.fontSize(10).font('Helvetica-Bold').fillColor('#cc0000').text('Dano Pre-existente: Sim').fillColor('#000000');
      doc.moveDown(0.3);
    }
    if (order.recommendations) {
      doc.fontSize(10).font('Helvetica-Bold').text('Recomendacoes:');
      doc.fontSize(10).font('Helvetica').text(order.recommendations, { indent: 10 });
      doc.moveDown(0.3);
    }

    // Before photo at bottom of page 1
    const beforePhotos = order.Photos.filter(p => p.type === 'before');
    const duringPhotos = order.Photos.filter(p => p.type === 'during');
    const afterPhotos = order.Photos.filter(p => p.type === 'after');

    if (beforePhotos.length > 0) {
      const remaining = MAX_Y - doc.y - 60;
      if (remaining < 120) doc.addPage();

      doc.fontSize(11).font('Helvetica-Bold').fillColor('#2563eb').text('ANTES').fillColor('#000000');
      doc.moveDown(0.2);
      const p = beforePhotos[0];
      const pPath = path.resolve(uploadDir(), p.filename);
      if (fs.existsSync(pPath)) {
        doc.image(pPath, MARGIN, doc.y, { width: PAGE_W, height: Math.min(220, MAX_Y - doc.y - 40) });
      }
    }

    // ====================== PAGE 2 ======================
    doc.addPage();

    // During photos
    if (duringPhotos.length > 0) {
      doc.fontSize(11).font('Helvetica-Bold').fillColor('#2563eb').text('DURANTE').fillColor('#000000');
      doc.moveDown(0.2);
      for (const p of duringPhotos) {
        const pPath = path.resolve(uploadDir(), p.filename);
        if (fs.existsSync(pPath)) {
          if (doc.y + 150 > MAX_Y) doc.addPage();
          doc.image(pPath, MARGIN, doc.y, { width: PAGE_W, height: 150 });
          doc.y += 155;
        }
      }
    }

    // After photos
    if (afterPhotos.length > 0) {
      if (doc.y + 150 > MAX_Y) doc.addPage();
      doc.fontSize(11).font('Helvetica-Bold').fillColor('#2563eb').text('DEPOIS').fillColor('#000000');
      doc.moveDown(0.2);
      for (const p of afterPhotos) {
        const pPath = path.resolve(uploadDir(), p.filename);
        if (fs.existsSync(pPath)) {
          if (doc.y + 150 > MAX_Y) doc.addPage();
          doc.image(pPath, MARGIN, doc.y, { width: PAGE_W, height: 150 });
          doc.y += 155;
        }
      }
    }

    // ====================== SIGNATURE ======================
    if (doc.y + 180 > MAX_Y) doc.addPage();

    const sigBlockY = Math.max(doc.y + 20, 630);
    doc.y = sigBlockY;

    if (order.clientSignature) {
      const sigData = order.clientSignature.replace(/^data:image\/png;base64,/, '');
      const sigBuffer = Buffer.from(sigData, 'base64');
      const sigPath = path.resolve(uploadDir(), 'sig_' + order.id + '.png');
      fs.writeFileSync(sigPath, sigBuffer);
      doc.image(sigPath, MARGIN + 15, doc.y, {
        fit: [280, 55],
        align: 'center',
        valign: 'bottom',
      });
      doc.y += 58;
    }

    doc.moveTo(MARGIN, doc.y).lineTo(310, doc.y).stroke();
    doc.moveDown(0.3);
    doc.fontSize(10).font('Helvetica').text('Assinatura do Cliente', MARGIN, doc.y, { width: 270, align: 'center' });
    doc.y += 20;

    // Footer
    if (doc.y > FOOTER_Y) doc.addPage();
    doc.moveTo(MARGIN, doc.y).lineTo(550, doc.y).stroke();
    doc.moveDown(0.3);
    doc.fontSize(8).font('Helvetica').text(
      `Relatorio gerado em ${new Date().toLocaleString('pt-BR')} | ${companyName}`,
      { align: 'center' }
    );

    doc.end();
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
