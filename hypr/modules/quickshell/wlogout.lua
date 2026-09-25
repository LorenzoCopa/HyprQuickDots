-- Wlogout overlay (Quickshell)
-- La ventana cubre el monitor con tamaño explícito en el QML (NUNCA
-- `fullscreen`: una ventana fullscreen se esconde en la esquina superior
-- izquierda al cerrarla y retiene ese estado). La regla flotante la mantiene
-- como ventana flotante centrada del tamaño del monitor.
hl.window_rule({
	name = "qs-wlogout-float",
	match = { title = "wlogout" },

	float = true,
	center = true,
	no_shadow = true,
	no_blur = true,
	border_size = 0,
	stay_focused = true,
	no_initial_focus = false,
})
