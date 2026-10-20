¿De qué manera el agente/chatbot respeta y fomenta los principios de la Declaración de la Persona Transhumana en el contexto del aprendizaje y la interacción tecnológica?


La vida es una gran apuesta.
Frente a mediciones peligrosas, como un 2.5 % de metano, el asistente sugiere primero una acción inmediata, como evacuar, apagar la energía o mejorar la ventilación, y menciona los umbrales con sus valores exactos.

Me estoy mejorando gracias a la ciencia y la tecnología.
Respondo utilizando RAG con una base de conocimiento propia (knowledge/*.md) y muestro las fuentes.Esto permite que el usuario aprenda y confirme de dónde provienen los datos, como gases, ventilación, Decreto 1886 de 2015 y la arquitectura del proyecto, tanto en español como en inglés.

Soy libre, autónomo y responsable.
El chatbot brinda información y orientación, pero no controla ventiladores ni alarmas.Estas acciones las realiza la persona a través de la aplicación, con roles, permisos y auditoría en PostgreSQL.

No causo daño.
Mi alcance está definido: temas fuera del proyecto, minería o ingeniería reciben respuestas fijas.Utilizo una baja temperatura (0.2), reglas de veracidad, confidencialidad de claves, validación de entrada y límites de tasa.

Promueve la paz y la armonía comunitaria.
Hago disponible el conocimiento sobre protocolos de emergencia para ingenieros, supervisores y mineros de Sutatausa, en un lenguaje claro, lo que fortalece una cultura preventiva compartida.

#
How does the implemented AI agent/chatbot align with and support the Transhuman Person Declaration of Universidad de Cundinamarca regarding ethical AI integration, human augmentation, and educational transformation?

Ethical AI integration. The assistant is bounded by a restricted-domain prompt, a fixed out-of-scope reply, low temperature (0.2), truthfulness rules, credential confidentiality, input validation, and rate limiting. For hazardous readings it leads with the immediate safety action, which serves the Declaration’s principle that life is the greatest wager of the 21st century.
Human augmentation, not replacement. It extends the operator’s knowledge and judgement by interpreting gas readings, converting units, estimating ventilation airflow, and explaining regulation. It never actuates equipment. Ventilation overrides and alarm acknowledgements remain human actions recorded in the PostgreSQL audit trail, so the person stays “free, autonomous, and responsible.”
Educational transformation. Through RAG, answers are grounded in an editable knowledge base and return their sources, which encourages verification instead of blind trust. Bilingual support (Spanish/English) and plain-language guidance turn the software into a learning companion for safety culture, regulation, and engineering, extending the university’s formative mission to the mine.
