# Prompt de razonamiento verificable (revisión técnica)

Realiza una auditoría reproducible sin exponer ni simular razonamientos privados internos. Evalúa cada función del script y documenta evidencia y limitaciones.

1. Comparar lista de funcionalidades de ArionCam, Lite v3 y v4B para evitar pérdidas.
2. Identificar fallos de orden de inicialización, capturas de variables y visibilidad de controles; razonar a partir del código reproducible, no de suposiciones sobre Delta.
3. Para cada estado (cámara, iluminación, GUI, inputs, HUD, zoom, lock), definir estado inicial, transición, reset, deshacer, salida y reejecución; verificar que cada transición sea reversible.
4. Simular táctil/ratón, pestañas, toggles, slider, reset/undo, cambio de modo, desmontaje y reejecución con mocks. Probar fallo de camera-bind y ausencia de cámara.
5. Revisar que la matemática de zoom, velocidad y oscuridad tenga neutral correcto, límites y no escriba propiedades de escenas en cada frame.
6. Revisar coste por frame, número de eventos, layout en pantallas pequeñas y conflictos de superposición. Registrar riesgos reales que el mock no puede demostrar.
7. Entregar resultados claros: validado en local / pendiente en Delta. Ante regresiones, corregir y repetir.

Criterio de aprobación: ausencia de fallos comprobables en el mock y equivalencia funcional verificable; no se confunde test simulado con dispositivo real.
