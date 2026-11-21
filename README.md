# ARION FREECAM — Final v7.0

**Roblox / Luau / cliente (Delta móvil y PC)**. Script completo legible, sin minificación ni límite artificial de tamaño. Basado en el primer `ArionCam`, la versión Lite v3 y la v4B que funcionó por carga remota.

## Instalación con GitHub

Repositorio: https://github.com/ytexpo9-pixel/arion-freecam

1. Sube `Arion_Freecam.lua`, `Arion_Loader.lua`, `Arion_Loader_Diagnostico.lua` y `README.md` a la **raíz** del repositorio en la rama `main` mediante **Add file → Upload files → Commit changes**.
2. Mantén el nombre **`Arion_Freecam.lua`** en las futuras actualizaciones: el enlace remoto será siempre el mismo.
3. Comprueba que la URL RAW muestre código: https://raw.githubusercontent.com/ytexpo9-pixel/arion-freecam/main/Arion_Freecam.lua
4. Ejecuta el siguiente cargador en Delta:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ytexpo9-pixel/arion-freecam/main/Arion_Freecam.lua"))()
```

Si falla, ejecuta `Arion_Loader_Diagnostico.lua` (copiando su contenido al ejecutor) y revisa los mensajes `[Arion Loader]` / `[Arion v7]`. **No se han subido estos archivos a GitHub automáticamente**.

**Migración segura:** conserva `Arion_Completa_v4B_Min_v6.lua` en GitHub como copia de emergencia hasta confirmar v7 en tu dispositivo. No hace falta borrar el repositorio ni los archivos anteriores para instalar v7.

## Interfaz

- **AR**, esquina superior izquierda: toca para abrir/cerrar el panel; arrastra para mover el acceso.
- **Barra rápida**, borde derecho: `CAM ON/OFF`, `CINE`, `SUAVE`, `RESET`, `UNDO`; la palabra **MOVER** permite arrastrarla, y `+/-` plegarla.
- **Panel con cinco pestañas:** `MOV` (movimiento, sensibilidad, suavizado, FOV), `CINE` (cámara cinematográfica), `LUZ` (exposición/oscuridad), `LOCK` (jugadores, seguimiento, partes del cuerpo), `GUI` (modo visual, ocultar HUD y opacidades, reset/undo).
- **Abrir un ajuste numérico:** toca su fila y desliza el control horizontal que aparece debajo.
- **CINE:** pulsar `CINE` activa la freecam si estaba apagada y abre un panel **separado**. Mantén flechas para subir, bajar, ir a izquierda/derecha; AVANZAR y RETROCEDER para moverte sobre el eje de mirada. Usa `ZOOM +/-` o desliza el control de zoom. Arrastra el rótulo `CINE / MOVER` para reubicarlo; `-` oculta solamente este controlador (el zoom continúa). Vuelve a mostrarlo desde la pestaña CINE.
- **Opacidad:** en la pestaña `GUI` puedes controlar por separado la transparencia del joystick, la barra rápida y el controlador cinematográfico. Un 0% los hace invisibles, aunque sus áreas aún pueden recibir entrada.
- **Modo Completa:** panel disponible. **Mínima:** panel oculto y controles táctiles más discretos, pero `AR` permite abrirlo. **Invisible:** oculta GUI y controles visibles; recupera con **F8** o **doble toque en la esquina superior izquierda**.
- **Controles:** móvil: joystick abajo a la izquierda, deslizar en zona libre para mirar, SUBIR/BAJAR abajo a la derecha. PC: WASD, QE, ratón derecho + movimiento. Funciona sin modificar Anchored ni AutoRotate del personaje.

## Ajustes visuales

`Luz` tiene rango de -100% a +100%, con neutral **0%**. `Oscuridad` tiene rango de 0% a 100%, con neutral **0%**. Su efecto suma exposición, nivel de luz ambiental y `ColorCorrectionEffect` local propio (`ArionColorGradeV7`). Los resultados pueden variar según el motor de iluminación y los scripts de cada juego. **No modifica luces de partes ni el ciclo día/noche**. El botón Restaurar iluminación recupera los valores guardados.

## Reset y deshacer

`RESET` detiene la freecam, restaura el tipo/sujeto/FOV/cámara previo, el HUD ajeno y la iluminación; restablece velocidad, suavizado, FOV, opacidades, zoom, estado de lock, modos, pestañas, posiciones y paneles. `UNDO` restaura los ajustes capturados inmediatamente antes del último reset, incluidos cámara, luz, zoom, HUD y posiciones de elementos flotantes. La operación de deshacer es de un solo uso por reset.

Cerrar (`X`) o reejecutar el script limpia las conexiones, acciones, efecto propio y cámara anterior. No graba video; los controles no son una herramienta de captura ni se altera físicamente el personaje.

## Verificación

En el ZIP se incluyen `PROMPT_DESARROLLO.md`, `PROMPT_REVISION.md`, `INFORME_PRUEBAS.md`, `tests/test_v7_mock.lua` y `tests/resultado_mock.log` para inspeccionar el trabajo. Con `texlua` disponible:

```bash
texlua tests/test_v7_mock.lua Arion_Freecam.lua
```

Las pruebas son simuladas y **no sustituyen la validación en Delta real**. La prueba intencional de fallo `BindToRenderStep` muestra un mensaje de error esperado en el log.
