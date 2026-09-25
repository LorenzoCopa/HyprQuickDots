-- Screenshot Manager window rules
hl.window_rule({
	name = "qs-screenshot-mode-float",
	match = { title = "qs-screenshot-mode" },
	float = true,
	center = true,
	no_shadow = true,
	no_blur = true,
	opaque = false,
	border_size = 0,
	stay_focused = true,
	no_initial_focus = false,
})

hl.window_rule({
	name = "qs-screenshot-preview-float",
	match = { title = "qs-screenshot-preview" },
	float = true,
	center = true,
	size = { 580, 520 },
	no_shadow = true,
	no_blur = true,
	opaque = false,
	border_size = 0,
	no_initial_focus = false,
})
