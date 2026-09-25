-- Dictado por voz con whisper.cpp (SUPER + D)
-- Toggle: pulsa para grabar, pulsa otra vez para transcribir y pegar en la
-- ventana enfocada. Si no hay ventana enfocada, el texto queda copiado en el
-- portapapeles. El estado visual es el OSD de quickshell (qs-dictation), una
-- superficie layer-shell: no es una ventana, así que NO necesita window_rule
-- ni ruta en QS_CLOSE_ROUTES (SUPER+X la ignoraría igualmente).
local shortcuts = require("modules.shortcuts")
shortcuts.bind("SUPER + D", function()
	hl.exec_cmd("qs ipc call dictation toggle")
end, nil, "Dictado por voz (grabar/transcribir)", "Quickshell")

-- ESC cancela la grabación en curso (dictado o comando de voz). El OSD
-- (qs-dictation / qs-voicecmd) es una superficie layer-shell sin foco (para
-- no robarle el foco a la app que recibe el texto), así que no puede capturar
-- la tecla por sí mismo: se enruta por IPC desde Hyprland. `non_consuming`
-- hace que la tecla siga llegando a la app enfocada, por lo que ESC no se
-- rompe en el resto del sistema (y si no se está grabando, cancel es un no-op
-- en shell.qml).
shortcuts.bind("Escape", function()
	hl.exec_cmd("qs ipc call dictation cancel")
	hl.exec_cmd("qs ipc call voicecmd cancel")
end, { non_consuming = true }, "Cancelar dictado o comando de voz", "Quickshell")