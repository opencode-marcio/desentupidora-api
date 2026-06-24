FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY package.json package-lock.json ./
RUN npm ci --only=production

COPY . .

RUN mkdir -p data uploads

EXPOSE 3000

CMD ["node", "src/index.js"]
