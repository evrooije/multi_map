multi_map = {}

multi_map.number_of_layers = 32
multi_map.day_light = 15
multi_map.night_light = 0
multi_map.bedrock = "multi_map:bedrock"
multi_map.skyrock = "multi_map:skyrock"
multi_map.water_height = 0
multi_map.seed = 835726

multi_map.layer_height = 65535 / multi_map.number_of_layers
multi_map.half_layer_height = multi_map.layer_height / 2

function multi_map.get_current_layer(y)
	for l = (multi_map.number_of_layers / -2), (multi_map.number_of_layers / 2) do
		if y >= (l * layer_height) - half_layer_height and y < (l * layer_height) + half_layer_height then
			return l
		end
	end
end

function multi_map.get_offset_y(y)
	return y - (multi_map.get_current_layer(y) * multi_map.layer_height)
end

minetest.register_node("multi_map:skyrock", {
	description = "Multi Map Impenetrable Skyblock",
	drawtype = "airlike",
	is_ground_content = false,
	sunlight_propagates = true,
	walkable = true,
	pointable = false,
	diggable = false,
	climbable = false,
	paramtype = "light",
})

minetest.register_node("multi_map:bedrock", {
	description = "Multi Map Impenetrable Bedrock",
	drawtype = "normal",
	tiles ={"multi_map_bedrock.png"},
	is_ground_content = false,
	walkable = true,
	pointable = false,
	diggable = false,
	climbable = false,
})

local mod_path = minetest.get_modpath("multi_map")
dofile(mod_path.."/mapgen.lua")
