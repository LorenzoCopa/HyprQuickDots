-- Clipboard Manager
hl.window_rule({
	name = "qs-clipboard-float",
	match = { title = "qs-clipboard" },
	float = true,
	center = true,
	size = { 420, 580 },
	no_shadow = true,
	no_blur = true,
	opaque = false,
	border_size = 0,
	stay_focused = true,
	no_initial_focus = false,
})
