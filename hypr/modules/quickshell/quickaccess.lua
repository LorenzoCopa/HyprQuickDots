-- Menú de acceso rápido (QuickAccess)
-- Ventana transparente con mosaicos en cajas (reproductor, apps, bandeja);
-- la base es transparente, así que sin sombra/blur/borde para que solo se
-- vean las cajas. Igual patrón que el launcher.
hl.window_rule({
	name = "qs-quickaccess-float",
	match = { title = "qs-quickaccess" },

	float = true,
	center = true,
	no_shadow = true,
	no_blur = true,
	border_size = 0,
	stay_focused = true,
	no_initial_focus = false,
})

-- Sin `fullscreen`: una ventana flotante del tamaño del monitor queda DETRÁS
-- de un juego a pantalla completa cubriente (p. ej. Dota 2) y no se puede
-- manipular, pero forzar fullscreen hace que Hyprland degrade el juego a
-- mosaico (solo una ventana puede ser fullscreen cubriente por workspace).
-- En Hyprland >= 0.56 las ventanas flotantes ya traen `allowedOverFullscreen`
-- = true por defecto (Window.hpp), así que el menú se pinta ENCIMA del juego
-- sin tocar su estado: no hace falta set_prop ni ningún campo de regla.
-- OJO: `allowed_over_fullscreen` NO es una prop válida de `hl.dsp.window.set_prop`
-- (da "Invalid prop name") ni un campo de `hl.window_rule` (da "unknown field").
-- Tampoco se le debe aplicar `fullscreen`: al hacerlo, Hyprland fija
-- m_allowedOverFullscreen = false y la ventana retiene ese estado entre
-- hide/show, quedando DETRÁS del juego.

-- SUPER + Q abre/cierra el menú. Al abrirse toma el foco y, como toda ventana
-- flotante, se pinta sobre el juego sin cambiarlo de estado.
local shortcuts = require("modules.shortcuts")
shortcuts.bind("SUPER + Q", function()
	hl.exec_cmd("qs ipc call quickaccess toggle")
end, nil, "Menú de acceso rápido", "Quickshell")
