# MINER CLC

Sistema de monitoreo de gases, control de ventilación y gestión de alertas para minería subterránea (Sutatausa, Cundinamarca). App Flutter + PostgreSQL + **asistente con IA (RAG + Gemini)**.

## Asistente de IA (chatbot)

| Requisito | Cómo se cumple |
|---|---|
| **LLM + contexto delimitado** | `server/llm.js` conecta con **Gemini** (configurable a OpenAI/Ollama). El bot solo atiende dudas de MINER CLC (soporte técnico y manual interactivo) y rechaza lo demás. |
| **Base de conocimiento (RAG)** | `knowledge/*.md` se divide en fragmentos y se recupera con **BM25** (`server/rag.js`); solo los fragmentos relevantes viajan al modelo. |
| **Prompt engineering** | `server/prompt.js`: system prompt con dominio restringido, reglas anti-alucinación, defensa ante prompt-injection, protocolo de emergencia y *few-shot* (en dominio / fuera de dominio / sin información). |
| **Seguridad** | La API key vive solo en el servidor (variables de entorno de Vercel); validación de entrada, límite de tasa y respaldo local si el LLM falla. |

```
Flutter (chatbot_dialog) ──POST /api/chat──▶ Vercel function
                                              ├─ RAG: BM25 sobre knowledge/*.md
                                              ├─ ¿fuera de dominio? → respuesta fija (sin LLM)
                                              └─ Gemini (system prompt + contexto + historial)
        ◀── { answer, sources, mode } ───────┘      (si falla → motor local de palabras clave)
```

Para ampliar el conocimiento del bot basta con agregar o editar archivos `.md` en `knowledge/` (un `#` por tema, `##` por sección).

## Declaración de la Persona Transhumana (Universidad de Cundinamarca)

El proyecto **MINER CLC** articula los postulados de la **Declaración de la Persona Transhumana** de la Universidad de Cundinamarca, demostrando que la ingeniería y la tecnología deben estar al servicio de la preservación de la vida, la naturaleza y la dignidad humana:

- **La Vida como la Gran Apuesta:** El sistema salva vidas previniendo asfixias e intoxicaciones mediante monitoreo en tiempo real de gases (CO, CH4, H2S, O2).
- **Perfeccionamiento a través de la Ciencia y Tecnología:** Empleo de software contemporáneo (Flutter, PostgreSQL, RAG y Google Gemini) como herramienta transformadora del entorno minero.
- **Actos Transformadores y Cuidado Ambiental:** El control automático de ventilación optimiza la calidad del aire mientras reduce el consumo energético innecesario.
- **Paz y Armonía Comunitaria:** La reducción de accidentes mineros en Sutatausa aporta serenidad y bienestar a las familias trabajadoras.

*(Ver análisis reflexivo detallado en `docs/declaracion_transhumana.md` y en la base RAG `knowledge/11-declaracion_persona_transhumana.md`).*

## Probar el backend en local

```bash
npm test                              # pruebas del RAG y del endpoint (LLM simulado)
GEMINI_API_KEY=tu_clave npx vercel dev   # API en http://localhost:3000/api/chat
curl -X POST localhost:3000/api/chat -H "Content-Type: application/json" \
     -d '{"message":"¿Cuál es el límite de metano?"}'
```

## Despliegue en Vercel (enlace en vivo)

1. Compila la app web apuntando al mismo dominio (usa `/api/chat` por defecto en web):
   ```bash
   flutter build web --release
   rm -rf web_dist && cp -r build/web web_dist      # (Windows: xcopy /E /I build\web web_dist)
   ```
2. Sube el repo a GitHub (público) incluyendo `web_dist/`.
3. En [vercel.com](https://vercel.com) → *Add New Project* → importa el repo. Framework: **Other**. `vercel.json` ya define la carpeta de salida y las funciones.
4. La API key de Google AI Studio se puede poner de dos formas:
   - **Desde la app:** botón 🔑 en el encabezado del chatbot → pegar la clave (en escritorio se guarda en `chatbot_settings.json`, ignorado por Git; en web solo dura la sesión). La app la envía al backend en el header `x-gemini-key`.
   - **Como variable del servidor:** `GEMINI_API_KEY` en *Settings → Environment Variables* (la clave de respaldo para todos los usuarios). Redespliega.
5. Verifica: `https://TU-APP.vercel.app/api/health` debe responder `{"ok":true,"llmConfigured":true,...}`.

> La versión web usa la base de datos simulada (`MockDatabaseStore`) porque un navegador no puede conectarse directo a PostgreSQL; la app de escritorio sí usa PostgreSQL.

## Seguridad antes de publicar el repo

- `notification_settings.json` (token de Telegram) está en `.gitignore`; usa `notification_settings.example.json` como plantilla.
- Contraseñas de staging/producción en `lib/config/environment_config.dart` son marcadores `CHANGE_ME_*`.
- Si alguna vez subiste un token o clave a un repo, **revócalo y genera uno nuevo**.
