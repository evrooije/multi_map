multi_map = {}

-- Shorthand alias, can be used when no mods are installed called mm or creating global mm
if not mm then
	mm = multi_map
end

-- External settings that can be set by mods using multi_map
multi_map.number_of_layers = 24		-- How may layers to generate
multi_map.layers_start_chunk = 0	-- Y level where to start generating layers, in chunks
multi_map.layer_height_chunks = 32	-- Height of each layer, in chunks

-- Either MT engine defaults or derived from above values, to be used for more readable calculations
multi_map.layer_height = multi_map.layer_height_chunks * 80
multi_map.layers_start = multi_map.layers_start_chunk * 80
multi_map.map_height = 61840
multi_map.map_min = -30912
multi_map.map_max = 30927
multi_map.half_layer_height = multi_map.layer_height / 2
multi_map.current_layer = nil

-- Can be overridden with someone's own values
multi_map.bedrock = "multi_map_core:bedrock"  -- Node to use to fill the bottom of a layer
multi_map.skyrock = "multi_map_core:skyrock"  -- Node to use to fill the top of a layer

-- Whether to generate a bedrock layer under a layer/ skyrock above a layer
multi_map.generate_bedrock = true
multi_map.generate_skyrock = true

-- Table with generator chains
multi_map.generators = {}
-- When no suitable generator is found, this generator is used as a fallback
multi_map.fallback_generator = nil

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

-- Get the absolute y center centerpoint for a given layer
-- current_layer = the layer for which to calculate the centerpoint, or if nil the current layer that multi_map is processing
function multi_map.get_absolute_centerpoint(current_layer)
	if current_layer then
		return multi_map.map_min + multi_map.layers_start + (current_layer * multi_map.layer_height) + multi_map.half_layer_height
	else
		return multi_map.map_min + multi_map.layers_start + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
	end
end

-- Get the offset y position, i.e. the y relative to the current layer's center point
-- y = absolute y value to be translated to y relative to layer center point
function multi_map.get_offset_y(y)
	local center_point = multi_map.map_min + multi_map.layers_start + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height

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
-- y = relative y value to be translated to absolute world y position
-- current_layer = the layer we are in or if nil the current layer multi_map is processing
function multi_map.get_absolute_y(y, current_layer)
	if current_layer then
		local center_point = multi_map.map_min + multi_map.layers_start + (current_layer * multi_map.layer_height) + multi_map.half_layer_height
		return y - center_point
	else
		local center_point = multi_map.map_min + multi_map.layers_start + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
		return y - center_point
	end
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

local last_used_layer = -1

-- Mmmmh, might make these local ...
multi_map.global_2d_maps = {}
multi_map.global_2d_params = {}
multi_map.global_2d_map_arrays = {}

local map_cache = {}

-- Register a named map for use as 2D map. A 3D map could potentially be
-- registered using this as well, but since this is specialized for
-- multiple different seeds per layer, multi_map provides this mechanism.
-- Note: The seed provided in the params is used to seed math.random
-- and each layer gets a randomized seed after that. As such, the noise
-- is still predictable/ reproducible
-- name = the name of the map
-- params = the noise parameters as per minetest standard
function multi_map.register_global_2dmap(name, params)
	math.randomseed(params.seed)
	multi_map.global_2d_params[name] = {}
	multi_map.global_2d_map_arrays[name] = {}

	for i = 0, multi_map.number_of_layers -1 do
		local new_params = {
			offset = params.offset,
			scale = params.scale,
			spread = {x=params.spread.x, y=params.spread.y, z=params.spread.z},
			seed = math.random(-1000000000000, 1000000000000),
			octaves = params.octaves,
			persist = params.persist
		}
		multi_map.global_2d_params[name][i] = new_params
	end
end

-- Get the named 2D map as flat array
-- name = name of the noise map
-- chulenxz = chunk length in 2 dimensions (xz)
-- minposxz = minimum 2D position (xz)
-- current layer = the layer for which to retrieve the map or nil to use multi_map's current layer
function multi_map.get_global_2dmap_flat(name, chulenxz, minposxz, current_layer)
	if not multi_map.global_2d_map_arrays[name] then
		minetest.log("error", "[multi_map] Trying to get an unregistered global 2D map")
	end

	if not map_cache[name] then
		if not current_layer then
			if multi_map.current_layer ~= last_used_layer then
				multi_map.global_2d_maps[name] = minetest.get_perlin_map(multi_map.global_2d_params[name][multi_map.current_layer], chulenxz)
			end
			map_cache[name] = multi_map.global_2d_maps[name]:get2dMap_flat(minposxz, multi_map.global_2d_map_arrays[name][multi_map.current_layer])
			return map_cache[name]
		else
			if current_layer ~= last_used_layer then
				multi_map.global_2d_maps[name] = minetest.get_perlin_map(multi_map.global_2d_params[name][current_layer], chulenxz)
			end
			map_cache[name] = multi_map.global_2d_maps[name]:get2dMap_flat(minposxz, multi_map.global_2d_map_arrays[name][current_layer])
		end
	end

	return map_cache[name]
end

-- Mmmmh, might make these local ...
multi_map.global_3d_maps = {}
multi_map.global_3d_params = {}
multi_map.global_3d_map_arrays = {}

-- Register a named map for use as 3D map. It is separated from the 2D case as that one
-- retruires a layer to be specified in order to get differently seeded noise maps per
-- layer. For 3D this is not an issue as the abslute y can be used to retrieve different
-- values from layer to layer. Hence the 3D case is separate
-- name = the name of the map
-- params = the noise parameters as per minetest standard
function multi_map.register_global_3dmap(name, params)
	multi_map.global_3d_params[name] = params
	multi_map.global_3d_map_arrays[name] = {}
end

-- Get the named 2D map as flat array
-- name = name of the noise map
-- chulenxyz = chunk length in 3 dimensions (xyz)
-- minposxyz = minimum 3D position (xyz)
function multi_map.get_global_3dmap_flat(name, chulenxyz, minposxyz)
	if not multi_map.global_3d_map_arrays[name] then
		minetest.log("error", "[multi_map] Trying to get an unregistered global 3D map")
	end

	if not map_cache[name] then
		if not multi_map.global_3d_maps[name] then
			multi_map.global_3d_maps[name] = minetest.get_perlin_map(multi_map.global_3d_params[name], chulenxyz)
		end
		map_cache[name] = multi_map.global_3d_maps[name]:get3dMap_flat(minposxyz, multi_map.global_3d_map_arrays[name])
	end

	return map_cache[name]
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
	if multi_map.layers_start + (multi_map.number_of_layers * multi_map.layer_height) > multi_map.map_height then
		minetest.log("error", "[multi_map] Number of layers for the given layer height exceeds map height!")
	end
	minetest.set_mapgen_params({mgname="singlenode"})
end)

-- Dump the current state of the multiple map layer generator, i.e. settings, registered generators,
-- registered noises
function multi_map.log_state()
	minetest.log("action", "[multi_map] Multiple map layer generator global settings")
	minetest.log("action", "[multi_map]  - Number of layers: "..multi_map.number_of_layers)
	minetest.log("action", "[multi_map]  - Layers start at: "..(multi_map.map_min + multi_map.layers_start))
	minetest.log("action", "[multi_map]  - Layer height: "..multi_map.layer_height)

	minetest.log("action", "[multi_map]")
	minetest.log("action", "[multi_map] Registered generators")
	if multi_map.fallback_generator then
		minetest.log("action", "[multi_map]  - "..debug.getinfo(multi_map.fallback_generator.generator).short_src:match("^.+/(.+)$").." (fallback)")
	end
	for k,v in pairs(multi_map.generators) do
		for l,b in pairs(multi_map.generators[k]) do
			minetest.log("action", "[multi_map]  - "..debug.getinfo(b.generator).short_src:match("^.+/(.+)$").." (layer "..k..")")
		end
	end

	minetest.log("action", "[multi_map]")
	minetest.log("action", "[multi_map] Registered global maps")
	for k,v in pairs(multi_map.global_2d_params) do
		minetest.log("action", "[multi_map]  - "..k.." (2D)")
	end
	for k,v in pairs(multi_map.global_3d_params) do
		minetest.log("action", "[multi_map]  - "..k.." (3D)")
	end

	minetest.log("action", "[multi_map]")
end

local firstrun = true

-- Here all the magic (or should I say mess..) happens!
minetest.register_on_generated(function(minp, maxp)
	if firstrun then
		minetest.log("action", "[multi_map]")
		minetest.log("action", "[multi_map] First on_generated call started, module state:")
		minetest.log("action", "[multi_map]")
		multi_map.log_state()
		firstrun = false
	end

	multi_map.set_current_layer(minp.y)
	local sidelen = maxp.x - minp.x + 1

	if multi_map.current_layer >= multi_map.number_of_layers then
		return
	end

	local offset_minp = { x = minp.x, y = multi_map.get_offset_y(minp.y), z = minp.z }
	local offset_maxp = { x = maxp.x, y = multi_map.get_offset_y(maxp.y), z = maxp.z }

	if  multi_map.generate_bedrock and
		multi_map.map_min + multi_map.layers_start + (multi_map.layer_height * multi_map.current_layer) == minp.y
	then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local vm_data = vm:get_data()

		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node[multi_map.bedrock])

		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)
	elseif	multi_map.generate_skyrock
			and (multi_map.map_min + multi_map.layers_start + (multi_map.layer_height * (multi_map.current_layer + 1)) - 80 == minp.y or
				 multi_map.map_min + multi_map.layers_start + (multi_map.layer_height * (multi_map.current_layer + 1)) - 160 == minp.y
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

	map_cache = {}
end)

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
