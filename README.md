# Arion Freecam — v4B de prueba

Este repositorio aloja la versión minificada de Arion Freecam para una prueba A/B en Delta.

## Archivos

- `Arion_Completa_v4B_Min_v6.lua`: código Lua completo minificado; **no probado en Delta con carga remota**.
- `Arion_Loader.lua`: cargador compacto, obtiene ese archivo mediante HTTP.
- `Arion_Loader_Diagnostico.lua`: informa de errores de descarga, compilación y ejecución inicial.

## Prueba

1. Publica este repositorio con visibilidad **Public** y rama principal `main`.
2. Abre la URL RAW y verifica que devuelve código Lua, no una página HTML.
3. Ejecuta primero el cargador de diagnóstico en una sesión nueva; consulta la consola si el GUI no aparece.
4. Compara contra la v3 minificada que ya se ha comprobado funcional. No ejecutes ambas a la vez.

La línea remota descarga el programa completo. No lo comprime ni corrige fallos de inicialización; el código debe proceder de un repositorio bajo tu control.

**URL RAW esperada:**

`https://raw.githubusercontent.com/ytexpo9-pixel/arion-frecam/main/Arion_Completa_v4B_Min_v6.lua`
