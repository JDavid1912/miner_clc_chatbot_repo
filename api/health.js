'use strict';
const { getIndex } = require('../server/rag');
module.exports = (req, res) => {
  res.status(200).json({ ok: true, provider: process.env.LLM_PROVIDER || 'gemini', llmConfigured: Boolean(process.env.GEMINI_API_KEY || process.env.OPENAI_API_KEY || process.env.OPENAI_BASE_URL), chunks: getIndex().N });
};
