# ¿Cómo funcionan y cómo se resuelven las alertas?

> Categoría: Alertas. Explicación del ciclo de vida de una alerta y cómo marcarla como resuelta.

**Gestión de Alertas en MINER CLC:**

**Clasificación de Alertas:**
• 🟢 **INFO:** Eventos del sistema, cambios de modo de ventilación o conexión de sensores.
• 🟡 **WARN (Advertencia):** Nivel de gas acercándose a límites permisibles. Requiere inspección preventiva.
• 🔴 **DANGER (Peligro):** Valor crítico superado. Se activa alarma visual y requiere acción inmediata.

**¿Cómo marcar una alerta como resuelta?**
1. Dirígete a la pestaña **"Alertas"** en el menú de la izquierda.
2. Identifica la alerta activa que ya fue atendida por la brigada de seguridad.
3. Haz clic en el botón verde **"Resolver"**.
4. El sistema registrará la fecha y hora exacta (`resolved_at`) en la base de datos PostgreSQL y la removerá del panel de alertas activas.
