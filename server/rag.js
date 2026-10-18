'use strict';
// RAG ligero: chunking por encabezados + recuperación BM25 sobre la base de conocimiento (knowledge/*.md)
const fs = require('fs');
const path = require('path');

const KNOWLEDGE_DIR = path.join(__dirname, '..', 'knowledge');
const STOPWORDS = new Set(('de la el en y a los las del se que por un una con para es al lo como mas pero sus le ya o este si porque esta entre cuando muy sin sobre tambien me hasta hay donde quien desde todo nos durante todos uno les ni contra otros ese eso ante ellos e esto mi antes algunos que unos yo otro otras otra el tanto esa estos mucho quienes nada muchos cual poco ella estar estas algunas algo nosotros mis tu te ti tu tus ellas nosotras vosotros vosotras os mio mia mios mias tuyo tuya tuyos tuyas suyo suya suyos suyas nuestro nuestra nuestros nuestras es son soy eres fue ser hacer puedo puede pueden quiero cual cuales').split(/\s+/));

function normalize(s) {
  return String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function stem(t) {
  // Stemmer ligero para español: quita plural y "e" final, y trunca a 6 caracteres
  if (t.length > 4 && t.endsWith('es')) t = t.slice(0, -2);
  else if (t.length > 3 && t.endsWith('s')) t = t.slice(0, -1);
  if (t.length > 3 && t.endsWith('e')) t = t.slice(0, -1);
  return t.length > 6 ? t.slice(0, 6) : t;
}

function tokenize(s) {
  return normalize(s)
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t && !STOPWORDS.has(t) && (t.length > 2 || /\d/.test(t) || t === 'co'))
    .map(stem);
}

function chunkFile(file, text) {
  const source = (text.match(/^#\s+(.+)$/m) || [null, file])[1].trim();
  const lines = text.split('\n');
  const sections = [];
  let heading = source;
  let buf = [];
  const flush = () => {
    const body = buf.join('\n').trim();
    if (body) sections.push({ heading, body });
    buf = [];
  };
  for (const line of lines) {
    const h = line.match(/^#{1,3}\s+(.+)$/);
    if (h) { flush(); heading = h[1].trim(); } else buf.push(line);
  }
  flush();
  const chunks = [];
  for (const s of sections) {
    // Divide secciones largas por párrafos (~1100 caracteres)
    const paras = s.body.split(/\n{2,}/);
    let cur = '';
    for (const p of paras) {
      if (cur && (cur.length + p.length) > 1100) { chunks.push({ source, heading: s.heading, text: cur.trim() }); cur = ''; }
      cur += (cur ? '\n\n' : '') + p;
    }
    if (cur.trim()) chunks.push({ source, heading: s.heading, text: cur.trim() });
  }
  return chunks.filter((c) => c.text.length > 40).map((c, i) => ({ ...c, id: `${file}#${i}` }));
}

let INDEX = null;
function buildIndex() {
  const chunks = [];
  for (const f of fs.readdirSync(KNOWLEDGE_DIR).filter((x) => x.endsWith('.md')).sort()) {
    chunks.push(...chunkFile(f, fs.readFileSync(path.join(KNOWLEDGE_DIR, f), 'utf8')));
  }
  const docs = chunks.map((c) => {
    // El título y el encabezado pesan el doble
    const toks = tokenize(`${c.source} ${c.heading} ${c.source} ${c.heading} ${c.text}`);
    const tf = new Map();
    toks.forEach((t) => tf.set(t, (tf.get(t) || 0) + 1));
    return { chunk: c, tf, len: toks.length };
  });
  const df = new Map();
  docs.forEach((d) => d.tf.forEach((_, t) => df.set(t, (df.get(t) || 0) + 1)));
  const avgLen = docs.reduce((a, d) => a + d.len, 0) / (docs.length || 1);
  return { docs, df, avgLen, N: docs.length };
}

function getIndex() { return INDEX || (INDEX = buildIndex()); }

// Devuelve los k fragmentos más relevantes con su puntaje BM25
function retrieve(query, k = 4) {
  const { docs, df, avgLen, N } = getIndex();
  const q = [...new Set(tokenize(query))];
  const k1 = 1.5, b = 0.75;
  const scored = docs.map((d) => {
    let score = 0;
    for (const t of q) {
      const f = d.tf.get(t);
      if (!f) continue;
      const idf = Math.log(1 + (N - df.get(t) + 0.5) / (df.get(t) + 0.5));
      score += idf * ((f * (k1 + 1)) / (f + k1 * (1 - b + b * (d.len / avgLen))));
    }
    return { ...d.chunk, score };
  });
  return scored.filter((s) => s.score > 0).sort((a, b2) => b2.score - a.score).slice(0, k);
}

module.exports = { retrieve, getIndex, tokenize };
