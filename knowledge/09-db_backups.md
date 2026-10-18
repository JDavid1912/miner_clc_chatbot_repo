# ¿Cómo realizar respaldos y consultar la base de datos?

> Categoría: Base de Datos. Información sobre la base de datos PostgreSQL, copias de seguridad y recuperación.

**Base de Datos y Respaldos en MINER CLC (Cumplimiento Anexo A):**

• **Motor:** PostgreSQL (`miner_clc` en `localhost:5432`).
• **Tablas:** `usuarios`, `lecturas_gases`, `ventilacion`, `alertas`, `auditoria_logs` y `respaldos_historial`.

**Cómo generar un respaldo:**
1. Ejecuta el script automatizado:
   `python scripts/backup_database.py`
2. El script generará un archivo `.sql` con timestamp y compresión, calculando el checksum criptográfico **SHA-256**.
3. El respaldo queda registrado automáticamente en la tabla `respaldos_historial` y en `auditoria_logs`.

*Para restaurar una copia, utiliza `python scripts/restore_database.py` indicando el archivo a restablecer.*
