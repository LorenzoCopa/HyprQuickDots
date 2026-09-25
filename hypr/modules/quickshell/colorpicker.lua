-- Color picker OSD (qs-colorpicker)
-- La ventana del OSD de color es un FloatingWindow de quickshell: necesita
-- regla de ventana para que Hyprland la trate como flotante centrada con su
-- tamaño pequeño; sin ella Hyprland la pondría en tile y saldría gigante.
hl.window_rule({
	name = "qs-colorpicker-float",
	match = { title = "qs-colorpicker" },
	float = true,
	center = true,
	size = { 420, 192 },
	no_shadow = true,
	no_blur = true,
	opaque = false,
	border_size = 0,
	stay_focused = true,
	no_initial_focus = false,
})