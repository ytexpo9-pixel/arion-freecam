# Auditoría técnica y matriz de regresión — Arion Final v7.0

Fecha: 2026-11-20. Fuentes inspeccionadas: `ArionCam` (primer script, 585 líneas), `Arion_Freecam_Lite_v3.lua` (380 líneas), `Arion_Freecam_Modular_v4.lua` (747 líneas), `Arion_v4B_Prueba_Inicializacion.lua` (753 líneas). Se priorizó GUI compatible con el patrón de arranque Lite v3 / v4B (sin guardia abortiva `Run:IsClient()`).

## Diagnóstico antes de cambios

- Zoom v4: `ZoomTray.Visible = S.active and S.zoom and S.mode==1`. El control se ocultaba en modo Mínima/Invisible, y su diseño anterior solo incluía una barra en el centro inferior; no ofrecía traslación cinematográfica independiente.
- Iluminación v4: `Lighting.Brightness=math.max(.5, ...)` impedía oscurecer por debajo de 0.5. También se aplicaba contraste positivo incluso en posición neutral y se mezclaban brillos/oscuridad en un solo slider.
- Interfaz v4: una única lista vertical de opciones requería desplazamiento excesivo. La v7 distribuye funciones en cinco pestañas y mantiene una barra lateral de acceso rápido.

## Matriz de funciones

| Función | Resultado v7 |
|---|---|
| GUI visible antes de freecam, compatibilidad cliente | Conservada y verificada en mock |
| Freecam, movimiento y mirada PC/táctil, alturas | Conservados; teclado/movimiento/hold CINE verificados |
| Velocidad, sensibilidad y FOV | Conservados; controles independientes |
| Modo suave ON/OFF y suavizado graduable | Conservados; ambos toggles rápidos verificados |
| Cine + zoom y desplazamiento externo | Nuevo panel flotante; activación, zoom, hold, liberación y drag verificados |
| Exposición/Luz y Oscuridad | Separados; exposición, cambio de iluminación y restauración comprobados |
| Opacidades de táctil, barra rápida y cine | Nuevo control separado de las tres áreas; verificado |
| Jugadores: seleccionar, observar, navegación, lock y partes | Conservados; selección, lock, aim a cabeza, seguimiento y salida verificados |
| Ocultar HUD y restaurar | Conservado; verificado en reset/undo/reejecución |
| Modos Completa/Mínima/Invisible + recuperación | Conservados; F8, doble toque y regreso desde mínima verificados |
| Reset/Undo, cierre, reejecución | Verificado en cámara, efectos visuales, HUD, zoom, posiciones |
| Cámara reemplazada durante freecam | Probado con mock |
| Fallo al vincular RenderStep | Probado inyectando error controlado; devuelve cámara |
| Evitar alterar Anchored/AutoRotate | Verificado en mock |

## Pruebas ejecutadas

- Comprobación sintáctica: `texlua` compiló el archivo Lua sin error. Esto **no es un compilador exclusivo de Luau**, pero el código evita sintaxis dependiente de Lua 5.4.
- Simulación de servicios Roblox y eventos: **105 aserciones correctas**, con resultados completos en `tests/resultado_mock.log`.
- Incluye arranque con `Run:IsClient()` falso en el mock, error intencional de `BindToRenderStep`, seguimiento, cierre y reejecución.
- No se ha ejecutado la GUI en Delta real; el mock no comprueba renderizado auténtico, accesibilidad táctil específica del cliente, rendimiento GPU, restricciones de una experiencia Roblox ni scripts externos que reescriben iluminación/cámara.

## Prioridades para validar en Delta

1. Tras publicar `Arion_Freecam.lua`, ejecutar el loader RAW. Confirmar `AR` y la barra rápida sin activar cámara. Si no aparecen, usar el loader diagnóstico.
2. En horizontal y vertical, arrastrar botón `AR`, cabecera, `MOVER` y `CINE`. Verificar que ninguno desaparezca fuera del marco y que el menú no tape por defecto el dock derecho.
3. Activar freecam, probar pad, mirada, SUBIR/BAJAR, CINE (flechas y AVANZAR/RETROCEDER), zoom +/- y slider. Cambiar modos visuales y recuperar con F8 o doble toque.
4. Ajustar Luz a -100%, +100% y neutro, Oscuridad a 100% y 0%; restaurar iluminación. Comparar visualmente en escenarios claros y oscuros.
5. Hacer RESET con cine/lock/HUD/oscuridad activos, comprobar restauración, luego UNDO. Cerrar, reejecutar y comprobar que no quedan efectos ni acciones duplicadas.

## Evidencia técnica / límites

- Se revisó documentación oficial Roblox de `GuiObject` y `UserInputService` (entrada táctil/ratón), `Lighting`, `ExposureCompensation` y `ColorCorrectionEffect`:
  - https://create.roblox.com/docs/reference/engine/classes/GuiObject
  - https://create.roblox.com/docs/reference/engine/classes/UserInputService
  - https://create.roblox.com/docs/reference/engine/classes/Lighting
  - https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect
- No puede garantizarse que todas las experiencias Roblox permitan o respeten permanentemente estos cambios: un juego puede reemplazar cámara o iluminación.
- No se ha medido FPS en el dispositivo. El RenderStep se vincula únicamente con la cámara activa y la GUI se actualiza por eventos, no cada frame.
- No se altera el personaje para congelarlo, ni se ofrecen mecanismos contra restricciones de juegos.
