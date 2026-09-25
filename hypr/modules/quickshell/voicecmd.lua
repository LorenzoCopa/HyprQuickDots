-- Comandos de voz (SUPER + A)
-- Toggle: pulsa para grabar el comando, pulsa otra vez para transcribirlo y
-- ejecutarlo (abrir app/servicio, control de música/volumen). El estado
-- visual es el OSD de quickshell (qs-voicecmd), una superficie layer-shell.
-- La cancelación con ESC se enruta desde dictation.lua (que ya posee el bind
-- `non_consuming` de Escape) para no duplicar binds sobre la misma tecla.
local shortcuts = require("modules.shortcuts")
shortcuts.bind("SUPER + A", function()
	hl.exec_cmd("qs ipc call voicecmd toggle")
end, nil, "Comando de voz (abrir apps, controlar música/volumen)", "Quickshell")