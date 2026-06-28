FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --only=production

COPY backend/ .

RUN mkdir -p data uploads

EXPOSE 3000

CMD ["node", "src/index.js"]
