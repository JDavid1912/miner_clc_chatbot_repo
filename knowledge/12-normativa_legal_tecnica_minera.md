# Normativa Legal Minera y Estándares Técnicos (Colombia e Internacional)

> Categoría: Normativa / Leyes y Aspectos Técnicos de Minería. Marco regulatorio aplicable a MINER CLC, ventilación subterránea y límites de gases.

## 1. Marco Legal Minero en Colombia

El software MINER CLC basa sus reglas de seguridad, detección de atmósferas peligrosas y ventilación en el marco legal de minería subterránea en Colombia:

- **Decreto 1886 de 2015 (Reglamento de Seguridad en las Labores Mineras Subterráneas):**
  - **Ventilación obligatoria (Título III):** Todas las labores subterráneas accesibles deben contar con ventilación continua que asegure el suministro mínimo de aire fresco por persona (mínimo legal de 3 m³/min por trabajador en atmósferas sin gases explosivos o según cálculo térmico y de maquinaria).
  - **Límites de metano (CH4 - Título III, Capítulo II):**
    - `0.5%`: Umbral preventivo normal en retorno de aire.
    - `1.0%`: Prohibición de voladuras y trabajos que generen chispas.
    - `≥ 2.0%`: Emergencia crítica inmediata. Orden de evacuación de todo el personal y suspensión obligatoria del suministro de energía eléctrica en el frente o galería.
  - **Contenido mínimo de Oxígeno (O2):** Mínimo legal del 19.5% en volumen. Si cae por debajo, se declara peligro por asfixia y se evacúa.
  - **Monóxido de Carbono (CO):** Límite máximo permisible de 25 ppm (TLV-TWA) y límite techo de 50 ppm.
  - **Ácido Sulfhídrico (H2S):** Concentración máxima permisible de 10 ppm (TLV-TWA) y techo de 15 ppm.

- **Código de Minas (Ley 685 de 2001):**
  - Establece los derechos, deberes y obligaciones de los titulares mineros, exigiendo planes de gestión ambiental, seguridad minera y cumplimiento de normas técnicas para proteger a los trabajadores y a la comunidad.

- **Resolución 2400 de 1979 (Estatuto de Seguridad Industrial):**
  - Disposiciones sobre higiene y seguridad en los lugares de trabajo, calidad del aire, prevención de riesgos por agentes químicos, asfixiantes y estrés térmico.

- **Decreto 1072 de 2015 (SG-SST):**
  - Sistema de Gestión de la Seguridad y Salud en el Trabajo: identificación de peligros, evaluación y valoración de riesgos en minería subterránea.

---

## 2. Parámetros y Fundamentos Técnicos de Ingeniería Minera

- **Ventilación Principal vs. Ventilación Secundaria/Auxiliar:**
  - *Ventilación Principal:* Ventiladores de superficie que inducen o expulsan el aire general de la mina a través de galerías, pozos y tambores.
  - *Ventilación Auxiliar:* Ventiladores y ductos impelentes/aspirantes que conducen aire fresco a frentes ciegos o zonas de avance donde la ventilación principal no llega directamente.
- **Modos de Ventilación en MINER CLC:**
  - *Modo Automático (Por Demanda):* Los algoritmos modulan el porcentaje de potencia de los ventiladores según las concentraciones en tiempo real de gases (CH4, CO, CO2, H2S) y temperatura.
  - *Modo Manual:* Permite a supervisores autorizados fijar la potencia de 0% a 100% ante mantenimientos, pruebas o protocolos específicos.
- **Riesgos Atmosféricos Principales:**
  - *Atmósferas Explosivas:* Formadas por mezcla de metano (grisú) con aire (rango explosivo del CH4: 5% a 15%, siendo 9.5% la mezcla más explosiva).
  - *Atmósferas Asfixiantes:* Deficiencia de oxígeno (< 19.5%) o desplazamiento por CO2 o nitrógeno.
  - *Atmósferas Tóxicas:* Presencia de monóxido de carbono (CO) por combustión incompleta o incendios subterráneos, y ácido sulfhídrico (H2S).

---

## 3. Legal and Technical Standards (English Summary)

- **Colombian Mining Safety Regulation (Decree 1886 of 2015):**
  - Regulates occupational health and atmospheric safety for underground coal and mineral mines in Colombia (e.g., Sutatausa, Cundinamarca).
  - **Methane (CH4) Rules:** Mandatory power shut-off and emergency evacuation when CH4 levels reach or exceed 2.0%. Warning and inspection when exceeding 1.0%.
  - **Oxygen (O2) Requirement:** Minimum legal volume of 19.5%. Immediate evacuation if below 19.5% due to chemical and physical asphyxiation risks.
  - **Toxic Gas Thresholds:** CO maximum continuous threshold is 25 ppm (> 50 ppm danger); H2S limit is 10 ppm (> 10 ppm dangerous toxicity).
- **Engineering Principles:**
  - Mine ventilation networks utilize demand-controlled ventilation (DCV) to optimize airflow, dilute contaminant gases, control thermal stress, and reduce fan electrical energy consumption.
