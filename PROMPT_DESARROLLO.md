# Prompt de implementación — Arion Freecam Final v7

Diseña e implementa un único archivo Roblox Luau cliente para Delta móvil y PC, empleando como fuentes el primer `ArionCam`, el script probado `Arion_Freecam_Lite_v3.lua` y la versión completa `Arion_v4B_Prueba_Inicializacion.lua`.

Objetivo: preservar todas las prestaciones funcionales: freecam, movimiento PC/táctil, sensibilidad/velocidad/FOV, suavizado ON/OFF y su intensidad, zoom cinematográfico, seguimiento de jugadores (anterior/siguiente), lock por torso/cabeza/torso bajo, HUD ocultable, tres modos de interfaz Completa/Mínima/Invisible con recuperación, controles arrastrables, controles de opacidad, reseteo y deshacer, cierre limpio, reejecución segura. No congelar físicamente al jugador.

Cambios obligatorios: tema oscuro moderno de alto contraste, panel por pestañas (Movimiento, Cine, Luz, Jugadores, Interfaz), barra rápida externa anclada al borde, controlador cinematográfico EXTERNO al panel, arrastrable, con flechas para desplazamiento de cámara, adelante/atrás, botones y slider de zoom, opacidad cinematográfica ajustable; control táctil de mira y joystick sin interferir con elementos de UI. Mantener accesos directos a reset y undo.

Corregir iluminación con dos parámetros independientes: luz -100..100 (neutral 0) y oscuridad 0..100 (neutral 0). Guardar valores base del servicio Lighting, modificar de forma reversible ExposureCompensation, Brightness, Ambient, OutdoorAmbient y un ColorCorrectionEffect propio. Sin modificar luces individuales ni scripts del juego. Reestablecer exactamente al reset y al cerrar; el deshacer debe recuperar estado de luz y parámetros.

Invariantes: sin `RunService:IsClient()` como guardia fatal, GUI inicializable en PlayerGui, GUI visible antes de activar cámara, sin hooks innecesarios en RenderStepped, sin fugas de conexiones, sin ScreenGui ajenos destruidos, restaurar CameraType/Subject/CFrame/Focus/FOV, limpieza del efecto de color, mapeo de inputs por identidad del toque, conservar opciones al reset/undo, robustez cuando cambia CurrentCamera o salen jugadores. Cargar remotamente por GitHub con nombre persistente `Arion_Freecam.lua`.

Entregables: script completo legible, loader y loader diagnóstico, README de instalación, prompt público de verificación, pruebas simuladas y un ZIP. Ejecutar verificaciones de sintaxis e inicialización; NO afirmar pruebas reales en Delta si no ocurrieron.
