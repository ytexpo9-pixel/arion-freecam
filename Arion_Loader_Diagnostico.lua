-- Arion Freecam v7 | Diagnostico de carga remota para Delta.
local URL="https://raw.githubusercontent.com/ytexpo9-pixel/arion-freecam/main/Arion_Freecam.lua"
print("[Arion Loader] 1/4: consultando URL RAW...")
local fetched,body=pcall(function() return game:HttpGet(URL) end)
if not fetched then
    warn("[Arion Loader] Error HTTP: "..tostring(body))
    return
end
if type(body)~="string" or #body<100 then
    warn("[Arion Loader] Respuesta vacia, corta o inesperada. Longitud: "..tostring(#body))
    return
end
print("[Arion Loader] 2/4: bytes descargados: "..#body)
local chunk,err=loadstring(body)
if not chunk then
    warn("[Arion Loader] Error al compilar: "..tostring(err))
    return
end
print("[Arion Loader] 3/4: compilacion OK; ejecutando...")
local ok,reason=pcall(chunk)
if not ok then
    warn("[Arion Loader] Error en arranque: "..tostring(reason))
    return
end
print("[Arion Loader] 4/4: arranque OK (comprobar GUI AR y consola [Arion v7])")
