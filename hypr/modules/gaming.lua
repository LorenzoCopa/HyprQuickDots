-- Gaming optimizations for Dota 2 and general games on Hyprland 0.56
-- MÓDULO COMENTADO COMPLETO (temporal, prueba de consumo de CPU con Dota abierto).
-- Para restaurar: quitar el bloque --[[ ... ]] de abajo.

--[[
-- Enable global allow_tearing for low-latency gaming (requires immediate = true in window rules)
hl.config({
	general = {
		allow_tearing = true,
	},
})

-- Dota 2 & Steam game optimizations
hl.window_rule({
	name = "dota2-gaming-optimizations",
	match = {
		class = "^(dota2|steam_app_570)$",
	},
	immediate = true, -- Low latency tearing
	idle_inhibit = "focus", -- Prevents screen idle/sleep while playing
	rounding = 0, -- Zero rounding for maximum performance and clean fullscreen
	-- confine_pointer = true, -- Keeps mouse pointer locked to the game window
	no_blur = true, -- Disables blur for performance
	no_shadow = true, -- Disables shadows
	no_anim = true, -- Disables animations
})
]]

-- Optional Game Mode toggle (SUPER + G) to maximize FPS by stripping all eyecandy globally
--[[
local gamemode_active = false
shortcuts.bind("SUPER + SHIFT + G", function()
	gamemode_active = not gamemode_active
	if gamemode_active then
		hl.config({
			general = {
				gaps_in = 0,
				gaps_out = 0,
				border_size = 0,
			},
			decoration = {
				rounding = 0,
				shadow = { enabled = false },
				blur = { enabled = false },
			},
			animations = {
				enabled = false,
			},
		})
		print("Game mode activated: Gaps, borders, shadows, blur, and animations disabled.")
	else
		hl.exec_cmd("hyprctl reload")
		print("Game mode deactivated: Restored default configuration.")
	end
end)
]]

-- Auto "no molestar" (do not disturb) notifications while a game has focus.
-- El bar (quickshell) expone los destinos IPC `notif-dnd autoDndOn/Off`.
--[[
local GAMING_DND_CLASSES = {
	"^dota2$",
	"^steam_app_570$",
	"^steam$",
	"^steam_app_%d+$",
	"^cs2$",
	"^Rust$",
}

local function is_gaming_class(class)
	if not class then
		return false
	end
	for _, pattern in ipairs(GAMING_DND_CLASSES) do
		if class:match(pattern) then
			return true
		end
	end
	return false
end

hl.on("window.active", function()
	local win = hl.get_active_window()
	local gaming = win and is_gaming_class(win.class) or false
	hl.exec_cmd("qs ipc call notif-dnd autoDnd" .. (gaming and "On" or "Off"))
end)
]]
