multi_map = {}

-- Shorthand alias, can be used when no mods are installed called mm or creating global mm
if not mm then
	mm = multi_map
end

multi_map.number_of_layers = 24		-- How may layers to generate
multi_map.layers_start_chunk = 0	-- Y level where to start generatint layers, in chunks
multi_map.layer_height_chunks = 32	-- Height of each layer, in chunks

-- Either engine defaults or derived from above values
multi_map.layer_height = multi_map.layer_height_chunks * 80
multi_map.map_height = 61840
multi_map.map_min = -30912
multi_map.map_max = 30927
multi_map.half_layer_height = multi_map.layer_height / 2
multi_map.current_layer = nil

-- Can be overridden with someone's own values
multi_map.bedrock = "multi_map_core:bedrock"
multi_map.skyrock = "multi_map_core:skyrock"

-- Whether to generate a bedrock layer under a layer/ skyrock above a layer
multi_map.generate_bedrock = true
multi_map.generate_skyrock = true

-- Chain of generators
multi_map.generators = {}
-- When no suitable generator is found, this generator is used as a fallback
multi_map.fallback_generator = nil

-- Set the current layer which the mapgen is generating
-- y = absolute y value to be translated to layer
function multi_map.set_current_layer(y)
	for l = 0, multi_map.number_of_layers do
		if y >= multi_map.map_min + (l * multi_map.layer_height)
		   and y < multi_map.map_min + ((l + 1) * multi_map.layer_height)
		then
			multi_map.current_layer = l
		end
	end
end

function multi_map.get_absolute_centerpoint(current_layer)
	if current_layer then
		return multi_map.map_min + (current_layer * multi_map.layer_height) + multi_map.half_layer_height
	else
		return multi_map.map_min + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
	end
end

-- Get the offset y position, i.e. the y relative to the current layer's center point
-- y = absolute y value to be translated to y relative to layer center point
function multi_map.get_offset_y(y)
	local center_point = multi_map.map_min + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height

	if center_point > 0 and y > 0 then
		return math.abs(y) - math.abs(center_point)
	elseif center_point < 0 and y < 0 then
		return math.abs(center_point) - math.abs(y)
	elseif center_point > 0 and y < 0 then
		return math.abs(y) - math.abs(center_point)
	else
		return center_point - y
	end
end

-- Get the absolute y position from a relative offset position
-- layer = the layer we are in
-- y = relative y value to be translated to absolute world y position
function multi_map.get_absolute_y(layer, y)
	local center_point = multi_map.map_min + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
	return y - center_point
end

-- Register a fallback generator, which is called in case not suitable generators are found for a layer
-- generator = the function to call
-- arguments = optional value or table with values that will be passed to the generator when called
function multi_map.register_fallback_generator(...)
	local arg = {...}
	local generator
	local arguments

	if arg[2] then
		generator = arg[1]
		arguments = arg[2]
	else
		generator = arg[1]
	end
	multi_map.fallback_generator = { generator = generator, arguments = arguments }
end

-- Register a generator for all if position is left out or one layer if position is specified
-- position = the optional layer for which call this generator
-- generator = the function to call
-- arguments = optional value or table with values that will be passed to the generator when called
function multi_map.register_generator(...)
	local arg = {...}
	local position
	local generator
	local arguments

	if arg[3] then
		position = arg[1]
		generator = arg[2]
		arguments = arg[3]
	elseif arg[2] then
		if type(arg[1]) == "function" then
			generator = arg[1]
			arguments = arg[2]
		else
			position = arg[1]
			generator = arg[2]
		end
	else
		generator = arg[1]
	end

	if not position then
		for i = 0, multi_map.number_of_layers - 1 do
			local t = multi_map.generators[i]
			if not t then
				t = {}
				multi_map.generators[i] = t
			end
			table.insert(t, { generator = generator, arguments = arguments })
		end
	else
		local t = multi_map.generators[position]
		if not t then
			t = {}
			multi_map.generators[position] = t
		end
		table.insert(t, { generator = generator, arguments = arguments })
	end
end

-- Helper to fill a chunk with a single type of node
function multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, content_id)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local vi = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				vm_data[vi] = content_id
				vi = vi + 1
			end
		end
	end
end

-- Helper to create a 1 node high plane on the specified y
function multi_map.generate_singlenode_plane(minp, maxp, area, vm_data, y, content_id)
	for z = minp.z, maxp.z do
		local vi = area:index(minp.x, y, z)
		for x = minp.x, maxp.x do
			vm_data[vi] = content_id
			vi = vi + 1
		end
	end
end

-- Inspired by duane's underworlds, to fetch the result of get_content_id once and cache it
multi_map.node = setmetatable({}, {
	__index = function(t, k)
		if not (t and k and type(t) == 'table') then
			return
		end

		t[k] = minetest.get_content_id(k)
		return t[k]
	end
})

minetest.register_on_mapgen_init(function(mapgen_params)
	if multi_map.number_of_layers * multi_map.layer_height > multi_map.map_height then
		minetest.log("error", "Number of layers for the given layer height exceeds map height!")
	end
	minetest.set_mapgen_params({mgname="singlenode"})
end)

minetest.register_on_generated(function(minp, maxp)
	multi_map.set_current_layer(minp.y)
	local sidelen = maxp.x - minp.x + 1

	if multi_map.current_layer >= multi_map.number_of_layers then
		return
	end

	local offset_minp = { x = minp.x, y = multi_map.get_offset_y(minp.y), z = minp.z }
	local offset_maxp = { x = maxp.x, y = multi_map.get_offset_y(maxp.y), z = maxp.z }

	if  multi_map.generate_bedrock and
		multi_map.map_min + (multi_map.layer_height * multi_map.current_layer) == minp.y
	then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local vm_data = vm:get_data()

		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node[multi_map.bedrock])

		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)
	elseif	multi_map.generate_skyrock
			and (multi_map.map_min + (multi_map.layer_height * (multi_map.current_layer + 1)) - 80 == minp.y or
				 multi_map.map_min + (multi_map.layer_height * (multi_map.current_layer + 1)) - 160 == minp.y
			)
	then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local vm_data = vm:get_data()

		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node[multi_map.skyrock])

		vm:set_lighting({day=15, night=0})
		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)
	else
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local vm_data = vm:get_data()
		local remove_shadow_caster = false

		-- Add a temporary stone layer above the chunk to ensure caves are dark
		if multi_map.get_absolute_centerpoint() >= maxp.y then
			if vm_data[area:index(minp.x, maxp.y + 1, minp.z)] == multi_map.node["ignore"] then
				remove_shadow_caster = true
				multi_map.generate_singlenode_plane(minp, maxp, area, vm_data, maxp.y + 1, multi_map.node["multi_map_core:shadow_caster"])
			end
		end

		local t = multi_map.generators[multi_map.current_layer]

		if not t then
			if multi_map.fallback_generator then
				multi_map.fallback_generator.generator(multi_map.current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp, multi_map.fallback_generator.arguments)
			else
				minetest.log("error", "Generator for layer "..multi_map.current_layer.." missing and no fallback specified, exiting mapgen!")
				return
			end
		else
			for i,f in ipairs(t) do
				f.generator(multi_map.current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp, f.arguments)
			end
		end

		vm:set_data(vm_data)
		vm:calc_lighting()
		vm:write_to_map()
		vm:update_liquids()

		-- Remove the temporary stone shadow casting layer again, if needed
		if remove_shadow_caster then
			if vm_data[area:index(minp.x, maxp.y + 1, minp.z)] == multi_map.node["multi_map_core:shadow_caster"] then
				multi_map.generate_singlenode_plane(minp, maxp, area, vm_data, maxp.y + 1, multi_map.node["ignore"])
				vm:set_data(vm_data)
				vm:write_to_map()
			end
		end

	end
end)

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
