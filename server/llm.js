'use strict';
// Conectores de LLM. Gemini por defecto; OpenAI-compatible cubre OpenAI, Ollama, Groq, etc.

async function postJson(url, headers, body, timeoutMs = 20000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body), signal: ctrl.signal });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`LLM HTTP ${res.status}: ${JSON.stringify(data).slice(0, 300)}`);
    return data;
  } finally { clearTimeout(timer); }
}

async function gemini(system, turns, keyOverride) {
  const key = keyOverride || process.env.GEMINI_API_KEY;
  if (!key) { const e = new Error('Falta GEMINI_API_KEY'); e.code = 'missing_key'; throw e; }

  // Modelos 100% gratuitos activos recomendados por Google AI Studio
  const candidateModels = [
    process.env.GEMINI_MODEL,
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
  ].filter(Boolean);

  let lastError = null;

  for (const model of candidateModels) {
    try {
      const data = await postJson(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        { 'x-goog-api-key': key },
        {
          systemInstruction: { parts: [{ text: system }] },
          contents: turns.map((t) => ({ role: t.role, parts: [{ text: t.text }] })),
          generationConfig: { temperature: 0.2, topP: 0.9, maxOutputTokens: 800 },
        },
      );
      const text = (data.candidates?.[0]?.content?.parts || []).map((p) => p.text || '').join('').trim();
      if (text) return text;
    } catch (err) {
      lastError = err;
      console.warn(`Modelo ${model} fallo (${err.message}). Probando siguiente...`);
    }
  }

  throw lastError || new Error('No se pudo generar respuesta con ninguno de los modelos de Gemini disponibles');
}

async function openaiCompatible(system, turns) {
  const base = (process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1').replace(/\/$/, '');
  const key = process.env.OPENAI_API_KEY || '';
  const data = await postJson(
    `${base}/chat/completions`,
    key ? { Authorization: `Bearer ${key}` } : {},
    {
      model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
      temperature: 0.2,
      max_tokens: 800,
      messages: [{ role: 'system', content: system }, ...turns.map((t) => ({ role: t.role === 'model' ? 'assistant' : 'user', content: t.text }))],
    },
  );
  const text = data.choices?.[0]?.message?.content?.trim();
  if (!text) throw new Error('Respuesta vacía del modelo');
  return text;
}

// userKey: clave de Google AI Studio que el usuario pegó en la app (tiene prioridad sobre la variable de entorno)
function generate(system, turns, userKey) {
  const provider = (process.env.LLM_PROVIDER || 'gemini').toLowerCase();
  return provider === 'gemini' ? gemini(system, turns, userKey) : openaiCompatible(system, turns);
}

module.exports = { generate };
