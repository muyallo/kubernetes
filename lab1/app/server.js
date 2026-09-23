const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = process.env.PORT || 3000;
const htmlPath = path.join(__dirname, 'index.html');

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      status: 'ok',
      pod: os.hostname()
    }));
  }

  if (req.url === '/') {
    const html = fs.readFileSync(htmlPath, 'utf8')
      .replace('', os.hostname());

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(html);
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Recurso no encontrado');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Aplicación disponible en el puerto ${PORT}`);
  console.log(`Hostname: ${os.hostname()}`);
});