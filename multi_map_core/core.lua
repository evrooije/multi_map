-- External settings that can be set by mods using multi_map
multi_map.number_of_layers = 24		-- How may layers to generate
multi_map.layers_start_chunk = 0	-- Y level where to start generating layers, in chunks
multi_map.layer_height_chunks = 32	-- Height of each layer, in chunks
multi_map.wrap_layers = false

-- Either MT engine defaults or derived from above values, to be used for more readable calculations
multi_map.layer_height = nil
multi_map.half_layer_height = nil
multi_map.layers_start = nil
multi_map.current_layer = nil

multi_map.map_height = 61840
multi_map.map_min = -30912
multi_map.map_max = 30927

-- Can be overridden with someone's own values
multi_map.bedrock = "multi_map_core:bedrock"  -- Node to use to fill the bottom of a layer
multi_map.skyrock = "multi_map_core:skyrock"  -- Node to use to fill the top of a layer

-- Whether to generate a bedrock layer under a layer/ skyrock above a layer/ shadow caster
-- above undeground mapchunks
multi_map.generate_bedrock = true
multi_map.generate_skyrock = true
multi_map.generate_shadow_caster = true

-- Table with layer specific configuration
multi_map.layers = {}
-- Table with generator chains
multi_map.generators = {}
-- When no suitable generator is found, this generator is used as a fallback
multi_map.fallback_generator = nil

local vm_data = {} -- reuse the massive VoxelManip memory buffer instead of creating on every on_generate()

-- Set the current layer which the mapgen is generating
-- y = absolute y value to be translated to layer
function multi_map.set_current_layer(y)
	for l = 0, multi_map.number_of_layers do
		if y >= multi_map.map_min + multi_map.layers_start + (l * multi_map.layer_height)
		   and y < multi_map.map_min + multi_map.layers_start + ((l + 1) * multi_map.layer_height)
		then
			multi_map.current_layer = l
		end
	end
end

-- Get a layer number for a given y, but do not set the current layer of the mapgen.
-- This can be used, for example, to get the layer number for a players coordinates
-- y = absolute y value to be translated to layer
function multi_map.get_layer(y)
	for l = 0, multi_map.number_of_layers do
		if y >= multi_map.map_min + multi_map.layers_start + (l * multi_map.layer_height)
		   and y < multi_map.map_min + multi_map.layers_start + ((l + 1) * multi_map.layer_height)
		then
			return l
		end
	end
end

-- Get a layer name for a given y, but do not set the current layer of the mapgen.
-- This can be used, for example, to get the layer number for a players coordinates
-- y = absolute y value to be translated to layer
function multi_map.get_layer_name_y(y)
	local l = multi_map.get_layer(y)
	if l and multi_map.layers[l] and multi_map.layers[l].name then
		return multi_map.layers[l].name
	else
		return tostring(l)
	end
end

-- Get the absolute y center centerpoint for a given layer
-- current_layer = the layer for which to calculate the centerpoint, or if nil the current layer that multi_map is processing
function multi_map.get_absolute_centerpoint(layer)
	if layer then
		return multi_map.map_min + multi_map.layers_start + (layer * multi_map.layer_height) + multi_map.half_layer_height
	else
		return multi_map.map_min + multi_map.layers_start + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
	end
end

-- Get the offset y position, i.e. the y relative to the current layer's center point
-- y = absolute y value to be translated to y relative to layer center point
function multi_map.get_offset_y(y, layer)
	local l
	if layer then
		l = layer
	else
		l = multi_map.current_layer
	end

	if not l then
		return y
	end

	local center_point = multi_map.map_min + multi_map.layers_start + (l * multi_map.layer_height) + multi_map.half_layer_height

	if center_point > 0 and y > 0 then
		return math.abs(y) - math.abs(center_point)
	elseif center_point < 0 and y < 0 then
		return math.abs(center_point) - math.abs(y)
	elseif center_point > 0 and y < 0 then
		return y - center_point -- 100, -80 -> 80 -100
	else
		return center_point - y
	end
end

-- Get the absolute y position from a relative offset position
-- y = relative y value to be translated to absolute world y position
-- current_layer = the layer we are in or if nil the current layer multi_map is processing
function multi_map.get_absolute_y(y, layer)
	if layer then
		local center_point = multi_map.map_min + multi_map.layers_start + (layer * multi_map.layer_height) + multi_map.half_layer_height
		return y - center_point
	else
		local center_point = multi_map.map_min + multi_map.layers_start + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
		return y - center_point
	end
end

multi_map.last_used_layer = -1

-- Register a fallback generator, which is called in case not suitable generators are found for a layer
-- name = the optional name for this generator, e.g. to be used for display on the HUD
-- generator = the function to call
-- arguments = optional value or table with values that will be passed to the generator when called
function multi_map.register_fallback_generator(...)
	local arg = {...}
	local name
	local generator
	local arguments

	if arg[3] then
		name = arg[1]
		generator = arg[2]
		arguments = arg[3]
	elseif arg[2] then
		if type(arg[1]) == "function" then
			generator = arg[1]
			arguments = arg[2]
		else
			name = arg[1]
			generator = arg[2]
		end
	else
		generator = arg[1]
	end
	multi_map.fallback_generator = { name = name, generator = generator, arguments = arguments }
end

function multi_map.set_layer_params(layer, layer_params)
	multi_map.layers[layer] = layer_params
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

-- Get the layer name, e.g. to use for display on the HUD
-- layer = the layer number
function multi_map.get_layer_name(layer)
	if multi_map.layers[layer] and multi_map.layers[layer].name then
		return multi_map.layers[layer].name
	elseif multi_map.fallback_generator then
		return multi_map.fallback_generator.name
	end
end

-- Helper to fill a map chunk with a single type of node
-- minp = minimum position vector, where to start filling
-- maxp = maximum position vector, where to end filling
-- area = voxel area
-- vm_data = the array with data for the voxel manipulator to fill
-- content_id = the content id of the node to use for filling the chunk
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
-- minp = minimum position vector, where to start filling
-- maxp = maximum position vector, where to end filling
-- area = voxel area
-- vm_data = the array with data for the voxel manipulator to fill
-- y = (absolute) y level to place the plane at
-- content_id = the content id of the node to use for filling the chunk
function multi_map.generate_singlenode_plane(minp, maxp, area, vm_data, y, content_id)
	for z = minp.z, maxp.z do
		local vi = area:index(minp.x, y, z)
		for x = minp.x, maxp.x do
			vm_data[vi] = content_id
			vi = vi + 1
		end
	end
end

-- Inspired by duane's underworlds, to fetch the result of get_content_id once and cache it.
-- Use: local c_air node["air"] -- get the content id for air
multi_map.node = setmetatable({}, {
	__index = function(t, k)
		if not (t and k and type(t) == 'table') then
			return
		end

		t[k] = minetest.get_content_id(k)
		return t[k]
	end
})

-- Simple init, does a sanity check of the settings and sets the mapgen to singlenode
minetest.register_on_mapgen_init(function(mapgen_params)
	minetest.set_mapgen_params({mgname="singlenode", flags="nolight"})
	minetest.after(0, function()
		multi_map.layer_height = multi_map.layer_height_chunks * 80
		multi_map.layers_start = multi_map.layers_start_chunk * 80
		multi_map.half_layer_height = multi_map.layer_height / 2

		if multi_map.layers_start + (multi_map.number_of_layers * multi_map.layer_height) > multi_map.map_height then
			minetest.log("error", "[multi_map] Number of layers for the given layer height exceeds map height!")
		end

		minetest.log("action", "[multi_map]")
		minetest.log("action", "[multi_map] First on_generated call started, module state:")
		minetest.log("action", "[multi_map]")
		multi_map.log_state()
	end)
end)

-- Here all the magic (or should I say mess...) happens!
minetest.register_on_generated(function(minp, maxp)
	multi_map.set_current_layer(minp.y)
	local sidelen = maxp.x - minp.x + 1

	if not multi_map.current_layer or multi_map.current_layer >= multi_map.number_of_layers then
		return
	end

	local offset_minp = { x = minp.x, y = multi_map.get_offset_y(minp.y), z = minp.z }
	local offset_maxp = { x = maxp.x, y = multi_map.get_offset_y(maxp.y), z = maxp.z }

	local generate_bedrock = multi_map.generate_bedrock
	local generate_skyrock = multi_map.generate_skyrock
	
	if multi_map.generate_bedrock then
		if multi_map.layers[multi_map.current_layer] and
		   multi_map.layers[multi_map.current_layer].generate_bedrock == false
		then
			generate_bedrock = false
		end
	else
		if multi_map.layers[multi_map.current_layer] and
		   multi_map.layers[multi_map.current_layer].generate_bedrock == true
		then
			generate_bedrock = true
		end
	end 

	if multi_map.generate_skyrock then
		if multi_map.layers[multi_map.current_layer] and
		   multi_map.layers[multi_map.current_layer].generate_skyrock == false
		then
			generate_skyrock = false
		end
	else
		if multi_map.layers[multi_map.current_layer] and
		   multi_map.layers[multi_map.current_layer].generate_skyrock == true
		then
			generate_skyrock = true
		end
	end 

	if  generate_bedrock and
		multi_map.map_min + multi_map.layers_start + (multi_map.layer_height * multi_map.current_layer) == minp.y
	then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		vm:get_data(vm_data)

		if	multi_map.layers[multi_map.current_layer] and
			multi_map.layers[multi_map.current_layer].bedrock_generator
		then
			multi_map.layers[multi_map.current_layer].bedrock_generator(multi_map.current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp)
		else
			multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node[multi_map.bedrock])
		end
		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)

	elseif	generate_skyrock
			and (multi_map.map_min + multi_map.layers_start + (multi_map.layer_height * (multi_map.current_layer + 1)) - 80 == minp.y or
				 multi_map.map_min + multi_map.layers_start + (multi_map.layer_height * (multi_map.current_layer + 1)) - 160 == minp.y
			)
	then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		vm:get_data(vm_data)

		if	multi_map.layers[multi_map.current_layer] and
			multi_map.layers[multi_map.current_layer].skyrock_generator
		then
			multi_map.layers[multi_map.current_layer].skyrock_generator(multi_map.current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp)
		else
			multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node[multi_map.skyrock])
		end
		vm:set_lighting({day=15, night=0})
		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)

	elseif multi_map.wrap_layers and multi_map.in_skip_area({ x = minp.x, y = minp.z }) then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		vm:get_data(vm_data)
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node["multi_map_core:skyrock"])
		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)
	else
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		vm:get_data(vm_data)
		local remove_shadow_caster = false

		-- Add a temporary shadow caster layer above the chunk to ensure caves are dark
		if (multi_map.generate_shadow_caster and multi_map.get_absolute_centerpoint() >= maxp.y) or
		   (multi_map.layers[multi_map.current_layer] and multi_map.layers[multi_map.current_layer].generate_shadow_caster == true)
		then
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
				minetest.log("error", "[multi_map] Generator for layer "..multi_map.current_layer.." missing and no fallback specified, exiting mapgen!")
				return
			end
		else
			for i,f in ipairs(t) do
				f.generator(multi_map.current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp, f.arguments)
			end
		end

		vm:set_data(vm_data)
		vm:calc_lighting()

		-- Remove the temporary stone shadow casting layer again, if needed
		if remove_shadow_caster then
			if vm_data[area:index(minp.x, maxp.y + 1, minp.z)] == multi_map.node["multi_map_core:shadow_caster"] then
				multi_map.generate_singlenode_plane(minp, maxp, area, vm_data, maxp.y + 1, multi_map.node["ignore"])
				vm:set_data(vm_data)
			end
		end

		vm:write_to_map()
		vm:update_liquids()

	end

	multi_map.last_used_layer = multi_map.current_layer
	multi_map.map_cache = {}
end)
