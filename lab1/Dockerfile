FROM node:24-alpine

WORKDIR /app

COPY app/package.json ./
COPY app/server.js ./
COPY app/index.html ./

ENV PORT=3000

EXPOSE 3000

USER node

CMD ["node", "server.js"]