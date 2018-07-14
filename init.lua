minetest.register_node("multi_map:skyrock", {
	description = "Multi Map Impenetrable Skyblock",
	drawtype = "airlike",
	is_ground_content = false,
	walkable = true,
	pointable = false,
	diggable = false,
	climbable = false,
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
