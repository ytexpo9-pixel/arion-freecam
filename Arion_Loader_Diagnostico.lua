-- Arion Freecam - Diagnostico de carga remota
local URL = "https://raw.githubusercontent.com/ytexpo9-pixel/arion-frecam/main/Arion_Completa_v4B_Min_v6.lua"
print("[Arion] Iniciando prueba de descarga")
local okFetch, source = pcall(function() return game:HttpGet(URL) end)
if not okFetch then warn("[Arion] Error HTTP:", source) return end
if type(source) ~= "string" or #source == 0 then warn("[Arion] Respuesta vacia o invalida") return end
print("[Arion] Descarga correcta. Bytes:", #source)
local fn, err = loadstring(source)
if not fn then warn("[Arion] Error de compilacion:", err) return end
print("[Arion] Compilacion correcta; iniciando")
local okRun, runtimeErr = pcall(fn)
if not okRun then warn("[Arion] Error de ejecucion:", runtimeErr) return end
print("[Arion] Chunk ejecutado; verificar GUI y consola si no aparece")
