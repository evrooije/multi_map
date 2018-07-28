multi_map = {}

-- Shorthand alias, can be used when no mods are installed called mm or creating global mm
if not mm then
	mm = multi_map
end

local multi_map_core_path = minetest.get_modpath("multi_map_core")

-- The various sourced files contain the remainder of the API, the
-- settings, node definitions and other core/ helper functionality
dofile(multi_map_core_path.."/core.lua")
dofile(multi_map_core_path.."/noise_mixer.lua")
dofile(multi_map_core_path.."/debug.lua")
dofile(multi_map_core_path.."/nodes.lua")
dofile(multi_map_core_path.."/hud.lua")
