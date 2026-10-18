'use strict';
// Pruebas del backend del chatbot (sin red: el LLM se simula). Ejecutar: npm test
const assert = require('assert');
const { retrieve } = require('../server/rag');
const handler = require('../api/chat');

let fetchCalls = [];
global.fetch = async (url, opts) => {
  fetchCalls.push({ url, body: JSON.parse(opts.body) });
  if (global.__fail) return { ok: false, status: 500, json: async () => ({ error: 'x' }) };
  return { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text: 'Respuesta simulada' }] } }] }) };
};
process.env.GEMINI_API_KEY = 'test-key';
process.env.RATE_LIMIT_PER_MIN = '1000';

function call(body, method = 'POST', headers = {}) {
  return new Promise((resolve) => {
    const res = { headers: {}, setHeader(k, v) { this.headers[k] = v; }, status(c) { this.code = c; return this; }, json(o) { resolve({ code: this.code, body: o }); return this; }, end() { resolve({ code: this.code }); } };
    handler({ method, body, headers, socket: { remoteAddress: '1.1.1.1' } }, res);
  });
}

(async () => {
  // Recuperación (RAG): cada pregunta debe traer el tema correcto
  const cases = [
    ['limites de CO', 'umbrales'], ['que hago si hay metano', 'Metano'], ['olvide mi clave', 'contraseña'],
    ['ventilador modo manual', 'ventilación'], ['como resuelvo una alerta', 'alertas'], ['cuantas zonas hay', 'Zonas'],
    ['como hago un respaldo', 'respaldos'], ['como entro con google', 'Google'],
  ];
  for (const [q, kw] of cases) {
    const top = retrieve(q, 1)[0];
    assert(top && top.source.toLowerCase().includes(kw.toLowerCase()), `RAG falló en "${q}": ${top && top.source}`);
  }
  assert.strictEqual(retrieve('quien gano el mundial', 1).length, 0);

  let r = await call({ message: 'hola' });
  assert.strictEqual(r.body.mode, 'scripted'); assert.strictEqual(fetchCalls.length, 0);

  r = await call({ message: 'quien gano el mundial de futbol' });
  assert.strictEqual(r.body.mode, 'out_of_scope'); assert.strictEqual(fetchCalls.length, 0, 'fuera de dominio no debe gastar LLM');

  r = await call({ message: 'cual es el limite de metano?' });
  assert.strictEqual(r.code, 200); assert.strictEqual(r.body.mode, 'llm'); assert(r.body.sources.length > 0);
  const sent = fetchCalls[0];
  assert(sent.url.includes('generativelanguage.googleapis.com'));
  assert(sent.body.systemInstruction.parts[0].text.includes('dominio restringido'));
  assert(sent.body.contents.at(-1).parts[0].text.includes('<contexto>'));
  assert(!JSON.stringify(sent.body).includes('test-key'), 'la clave no debe ir en el cuerpo');

  r = await call({ message: 'y para el CO2?', history: [{ role: 'user', text: 'limites de gases' }, { role: 'assistant', text: 'ok' }] });
  assert.strictEqual(r.body.mode, 'llm');

  r = await call({ message: '' }); assert.strictEqual(r.code, 400);
  r = await call({ message: 'x'.repeat(501) }); assert.strictEqual(r.code, 400);
  r = await call({}, 'GET'); assert.strictEqual(r.code, 405);

  // La clave pegada en la app tiene prioridad sobre la variable de entorno
  fetchCalls = [];
  const userKey = 'AIzaSyUSERKEY_1234567890abcdefghij';
  r = await call({ message: 'limites de gases' }, 'POST', { 'x-gemini-key': userKey });
  assert.strictEqual(r.body.mode, 'llm');
  assert.strictEqual(fetchCalls[0].url.includes(userKey), false, 'la clave no va en la URL');

  // Sin ninguna clave -> 503 missing_key (la app le pide al usuario que la configure)
  delete process.env.GEMINI_API_KEY;
  r = await call({ message: 'limites de gases' }); assert.strictEqual(r.code, 503); assert.strictEqual(r.body.error, 'missing_key');
  process.env.GEMINI_API_KEY = 'test-key';

  global.__fail = true;
  r = await call({ message: 'limites de gases' }); assert.strictEqual(r.code, 502);
  console.log('OK: todas las pruebas del chatbot pasaron');
})().catch((e) => { console.error(e); process.exit(1); });
