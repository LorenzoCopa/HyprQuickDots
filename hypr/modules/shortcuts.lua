-- Registro único de atajos de teclado.
--
-- `shortcuts.bind()` hace de pasarela a `hl.bind` (misma firma, mismo
-- resultado) y además apunta cada combinación a una descripción y una
-- categoría en español. `shortcuts.dump()` escribe ~/.config/quickshell/
-- shortcuts.json con TODO lo registrado; esa lista la lee la sección
-- "Atajos" de la Configuración de quickshell (con buscador y agrupación).
--
-- Así hay UNA sola fuente de verdad: si un bind cambia o se añade aquí
-- (o en los módulos que también usan shortcuts.bind), la sección refleja
-- exactamente los atajos reales tras `hyprctl reload`, sin listas
-- duplicadas que se queden desincronizadas.
--
-- Los binds que usen `hl.bind` DIRECTAMENTE (sin pasar por esta pasarela)
-- no aparecerán en la lista: si añades uno nuevo, regístralo con
-- shortcuts.bind() (o shortcuts.entry() para gestos/atajos sin bind).

local M = {}

local HOME = os.getenv("HOME") or ""
local OUT = HOME .. "/.config/quickshell/shortcuts.json"

M.entries = {}

local function esc(s)
	s = s:gsub("[\\\"]", "\\%0")
	s = s:gsub("%c", function(c)
		return string.format("\\u%04X", c:byte())
	end)
	return s
end

-- Registra un bind real: pasa a hl.bind (devuelve su handle, para poder
-- hacer set_enabled/etc.) y lo apunta con descripción y categoría.
function M.bind(keys, action, opts, desc, cat)
	M.entries[#M.entries + 1] = {
		keys = keys,
		desc = desc or "",
		cat = cat or "Otros",
	}
	return hl.bind(keys, action, opts)
end

-- Registra un atajo sin bind asociado (p. ej. gestos del touchpad).
function M.entry(keys, desc, cat)
	M.entries[#M.entries + 1] = {
		keys = keys,
		desc = desc or "",
		cat = cat or "Otros",
	}
end

-- Vuelca el registro a shortcuts.json (formato querido por el JsonAdapter
-- de la sección: un objeto con la clave `items`).
function M.dump()
	local out = { '{\n  "items": [' }
	local first = true
	for _, e in ipairs(M.entries) do
		if not first then
			out[#out + 1] = ","
		end
		first = false
		out[#out + 1] = "\n    {\n"
		out[#out + 1] = '      "keys": "' .. esc(e.keys) .. '",\n'
		out[#out + 1] = '      "desc": "' .. esc(e.desc) .. '",\n'
		out[#out + 1] = '      "cat": "' .. esc(e.cat) .. '"\n'
		out[#out + 1] = "    }"
	end
	out[#out + 1] = "\n  ]\n}\n"
	local f = io.open(OUT, "w")
	if f then
		f:write(table.concat(out))
		f:close()
	end
end

return M