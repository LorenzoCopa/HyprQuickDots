-- Wallpaper Picker window rules
hl.window_rule({
	name = "qs-wallpaper-float",
	match = { title = "qs-wallpaper" },
	float = true,
	center = true,
	size = { 600, 500 },
	no_shadow = true,
	no_blur = true,
	opaque = false,
	border_size = 0,
	stay_focused = true,
	no_initial_focus = false,
})
