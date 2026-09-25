-- App Launcher
-- El TAMAÑO lo controla el QML (ventana base fija; el recuadro visible crece
-- según los resultados), por eso no se fija `size` aquí. La ventana base es
-- transparente y sin sombra/blur/borde para que solo se vea el recuadro.
hl.window_rule({
	name = "qs-launcher-float", -- Nombre opcional pero recomendado
	match = { title = "qs-launcher" }, -- Coincide con el título de tu ventana

	-- Efectos que quieres aplicar
	float = true, -- Hace que flote
	center = true, -- La centra en la pantalla
	no_shadow = true, -- Sin sombra (la ventana base es transparente)
	no_blur = true, -- Sin desenfoque (no se ve el "marco" borroso sobre lo transparente)
	border_size = 0, -- Sin borde
	stay_focused = true, -- Mantiene el foco mientras está abierta
	no_initial_focus = false,

	-- monitor = "focused",
	-- monitor = "active",
})

-- App Browser (navegador de aplicaciones por categorías + rejilla)
-- SIN regla de ventana: se abre EN MOSAICO como una app cualquiera
-- (antes flotaba centrada con stay_focused). Se cierra con ESC, el ✕
-- o SUPER+X (QS_CLOSE_ROUTES); no hay FocusGrab que lo cierre al
-- perder el foco.

hl.window_rule({
	name = "qs-warmer-float",
	match = { title = "qs-warmer" },
	float = true,
	center = true,
	rounding = 0, -- Sin bordes redondeados
	opacity = 0, -- Totalmente transparente
	opaque = false, -- No opaco
	xray = false, -- Desactiva rayos X
})
