'use strict';
const { retrieve } = require('../server/rag');
const {
  SYSTEM_PROMPT,
  buildContents,
  OUT_OF_SCOPE,
  OUT_OF_SCOPE_EN,
  GREETING,
  GREETING_EN,
  THANKS,
  THANKS_EN,
} = require('../server/prompt');
const { generate } = require('../server/llm');

const MIN_SCORE = Number(process.env.RAG_MIN_SCORE || 0.6); // umbral calibrado para consultas en inglés/español
const hits = new Map(); // límite de tasa en memoria (mejor esfuerzo en serverless)

function rateLimited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter((t) => now - t < 60000);
  arr.push(now);
  hits.set(ip, arr);
  return arr.length > Number(process.env.RATE_LIMIT_PER_MIN || 30);
}

const norm = (s) => s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z\s]/g, ' ').replace(/\s+/g, ' ').trim();

const isGreetingEs = (q) => /^(hola|buenas|buenos dias|buenas tardes|buenas noches|que tal|saludos)( .{0,15})?$/.test(norm(q));
const isGreetingEn = (q) => /^(hello|hi|hey|good morning|good afternoon|good evening)( .{0,15})?$/.test(norm(q));

const isThanksEs = (q) => /^(muchas )?gracias|^perfecto|^listo gracias|^ok gracias/.test(norm(q));
const isThanksEn = (q) => /^(thank you|thanks|thank you very much|perfect thanks)/.test(norm(q));

const looksEnglish = (s) => {
  const words = norm(s).split(/\s+/);
  const enWords = new Set([
    'hello', 'hi', 'hey', 'what', 'how', 'where', 'when', 'who', 'why', 'can', 'could', 'is', 'are', 'the',
    'limits', 'gas', 'mine', 'mining', 'project', 'university', 'system', 'ventilation', 'law', 'laws',
    'regulation', 'regulations', 'standard', 'standards', 'safety', 'worker', 'workers', 'tell', 'explain',
    'about', 'please', 'with', 'from', 'does', 'do', 'which', 'threshold', 'thresholds', 'hazard', 'hazard',
    'alarm', 'emergency', 'sensors', 'underground', 'engineering', 'technical', 'rules', 'colombia', 'decree'
  ]);
  const count = words.filter((w) => enWords.has(w)).length;
  return count >= 1;
};

// Detecta si la consulta trata sobre temas afines a minería, ingeniería, normatividad, leyes o técnica
const isDomainRelevant = (s) => {
  const text = norm(s);
  return /(ley|leyes|decreto|norma|normativa|estandar|codigo|reglamento|articulo|resolucion|sg sst|mineria|minero|mina|minas|subterranea|gas|gases|metano|oxigeno|monoxido|carbono|sulfhidrico|ch4|co2|h2s|co|o2|ventilacion|ventilador|flujo|ingenieria|tecnico|tecnica|seguridad|evacuacion|sensor|alarma|sensorica|sutatausa|miner|transhumana|udec|cundinamarca|law|laws|decree|regulation|mining|mine|gas|methane|oxygen|hazard|emergency|threshold|technical)/.test(text);
};

async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', process.env.ALLOWED_ORIGIN || '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-gemini-key');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });

  const ip = String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'anon').split(',')[0].trim();
  if (rateLimited(ip)) return res.status(429).json({ error: 'Demasiadas solicitudes, intenta en un minuto.' });

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  if (!message || message.length > 500) return res.status(400).json({ error: 'Mensaje vacío o mayor a 500 caracteres.' });
  const history = Array.isArray(body.history)
    ? body.history.filter((h) => h && typeof h.text === 'string' && ['user', 'assistant'].includes(h.role)).slice(-6)
    : [];

  if (isGreetingEs(message)) return res.status(200).json({ answer: GREETING, sources: [], mode: 'scripted' });
  if (isGreetingEn(message)) return res.status(200).json({ answer: GREETING_EN, sources: [], mode: 'scripted' });

  if (isThanksEs(message)) return res.status(200).json({ answer: THANKS, sources: [], mode: 'scripted' });
  if (isThanksEn(message)) return res.status(200).json({ answer: THANKS_EN, sources: [], mode: 'scripted' });

  // La consulta de recuperación incluye el turno previo del usuario para resolver preguntas de seguimiento
  const lastUser = [...history].reverse().find((h) => h.role === 'user');
  const chunks = retrieve(`${message} ${lastUser ? lastUser.text : ''}`, 4);
  const top = retrieve(message, 1)[0];
  const relevant = (top && top.score >= MIN_SCORE) || (lastUser && chunks[0] && chunks[0].score >= MIN_SCORE * 1.5) || chunks.length > 0 || isDomainRelevant(message);
  if (!relevant) {
    const isEn = looksEnglish(message);
    return res.status(200).json({ answer: isEn ? OUT_OF_SCOPE_EN : OUT_OF_SCOPE, sources: [], mode: 'out_of_scope' });
  }

  // Clave opcional enviada por la app (campo "API Key" del chatbot). Nunca se registra en logs.
  const rawKey = String(req.headers['x-gemini-key'] || '').trim();
  const userKey = /^[A-Za-z0-9_.\-]{20,160}$/.test(rawKey) ? rawKey : undefined;
  if (!userKey && !process.env.GEMINI_API_KEY && (process.env.LLM_PROVIDER || 'gemini') === 'gemini') {
    return res.status(503).json({ error: 'missing_key' });
  }

  try {
    const answer = await generate(SYSTEM_PROMPT, buildContents(history, message, chunks), userKey);
    const sources = [...new Set(chunks.map((c) => c.source))].slice(0, 3);
    return res.status(200).json({ answer, sources, mode: 'llm' });
  } catch (e) {
    console.error('LLM error:', String(e.message).replace(/[A-Za-z0-9_.\-]{30,}/g, '***'));
    const bad = /HTTP (400|401|403)/.test(e.message) && userKey;
    return res.status(bad ? 401 : 502).json({ error: bad ? 'invalid_key' : `Error en LLM: ${e.message}` });
  }
}

module.exports = handler;