-- Skyrock is an invisible/ airlike node that is fully lit and
-- blocks shadow propagation by allowing sunlight to propagate
-- to below layers. Though airlike, it blocks player movement
-- so that the underside of a layer (e.g. bedrock or any other
-- mechanism) is not seen when approaching a layer's y limit
minetest.register_node("multi_map_core:skyrock", {
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

-- The shadow caster is used underground to create dark caves
-- since multi_map requires water_level to be set to -31000.
-- This water level allows every layer's overworld to be lit
-- and shaded properly using the engine's light calculation
-- but causes caves to be lit as well. By placing this layer
-- above the chunk being generated and then removing it after,
-- the map chunk is darkened properly as if it was underground
minetest.register_node("multi_map_core:shadow_caster", {
	description = "Multi Map Shadow Caster",
	drawtype = "airlike",
	is_ground_content = false,
	sunlight_propagates = false,
	walkable = false,
	pointable = false,
	diggable = false,
	climbable = false,
})

-- Bedrock layer that can be used as the bottom of the layer
-- to avoid players moving from one layer to another outside
-- of other means such as teleporters
minetest.register_node("multi_map_core:bedrock", {
	description = "Multi Map Impenetrable Bedrock",
	drawtype = "normal",
	tiles ={"multi_map_bedrock.png"},
	is_ground_content = false,
	walkable = true,
	pointable = false,
	diggable = false,
	climbable = false,
})
