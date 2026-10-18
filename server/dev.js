'use strict';
// Servidor local para probar el chatbot SIN Vercel:  npm start  (http://localhost:3000)
const http = require('http');
const fs = require('fs');
const path = require('path');

// Carga simple de .env si existe
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx !== -1) {
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim();
      if (!process.env[key]) {
        process.env[key] = val;
      }
    }
  }
}

const chat = require('../api/chat');
const health = require('../api/health');

http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  // Adaptadores mínimos para imitar el objeto res de Vercel
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (o) => { res.setHeader('Content-Type', 'application/json; charset=utf-8'); res.end(JSON.stringify(o)); return res; };

  if (url === '/api/health') return health(req, res);
  if (url !== '/api/chat') return res.status(404).json({ error: 'No encontrado' });

  if (req.method === 'OPTIONS') {
    return chat(req, res);
  }

  let raw = '';
  req.on('data', (d) => (raw += d));
  req.on('end', () => {
    try { req.body = raw ? JSON.parse(raw) : {}; } catch { return res.status(400).json({ error: 'JSON inválido' }); }
    chat(req, res);
  });
}).listen(process.env.PORT || 3000, () => console.log(`Chatbot API en http://localhost:${process.env.PORT || 3000}/api/chat`));
