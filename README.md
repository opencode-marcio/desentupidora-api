# Desentupidora App - Sistema de Comprovação de Serviço

## Estrutura

```
desentupidora/
├── backend/          # API Node.js + SQLite (dev) / PostgreSQL (prod)
│   ├── src/
│   │   ├── routes/       # auth, serviceOrders, photos, reports
│   │   ├── models/       # User, ServiceOrder, Photo
│   │   ├── middleware/    # auth, validate
│   │   └── index.js      # entry point
│   ├── Dockerfile
│   ├── .env.example
│   └── package.json
├── mobile/           # App Flutter
│   └── lib/src/
│       ├── screens/      # login, register, home, new order, order detail, settings
│       ├── services/     # API client, API config
│       └── models/       # data models
├── docker-compose.yml
└── README.md
```

## Como Rodar (Desenvolvimento)

### Backend
```bash
cd backend
cp .env.example .env
npm install
npm start
# roda em http://localhost:3000
```

### Mobile (Flutter)
```bash
cd mobile
flutter pub get
flutter run
# Configure a URL da API nas Configurações do app
```

## Deploy (Produção)

### Docker (Recomendado)
```bash
# Na raiz do projeto
docker compose up -d
# API em http://localhost:3000
```

### Sem Docker
1. Configure um banco PostgreSQL
2. Copie `.env.example` para `.env` e preencha `DATABASE_URL`
3. `npm ci --only=production`
4. `node src/index.js`

### Build do APK
```bash
cd mobile
flutter build apk --release
# O APK estará em build/app/outputs/flutter-apk/
```

## API Endpoints

- `POST /api/auth/register` - Cadastro (valida nome, email, senha 6+)
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Dados do usuário logado
- `GET /api/orders?page=1&limit=50` - Listar ordens (paginado)
- `POST /api/orders` - Criar ordem (valida cliente e endereço)
- `GET /api/orders/:id` - Detalhe da ordem
- `PUT /api/orders/:id` - Atualizar ordem
- `DELETE /api/orders/:id` - Remover ordem
- `POST /api/photos/upload/:orderId` - Upload de fotos (até 20, com watermark GPS)
- `DELETE /api/photos/:id` - Remover foto
- `GET /api/reports/:orderId/pdf` - Baixar relatório em PDF
