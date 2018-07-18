multi_map = {}

multi_map.number_of_layers = 24
multi_map.layer_height_chunks = 32
multi_map.layer_height = multi_map.layer_height_chunks * 80
multi_map.map_height = 61840
multi_map.map_min = -30912
multi_map.map_max = 30927
multi_map.half_layer_height = multi_map.layer_height / 2
multi_map.current_layer = nil

multi_map.bedrock = "multi_map_core:bedrock"
multi_map.skyrock = "multi_map_core:skyrock"

multi_map.generate_bedrock = true
multi_map.generate_skyrock = true

multi_map.generators = {}
multi_map.fallback_generator = nil

function multi_map.set_current_layer(y)
	for l = 0, multi_map.number_of_layers do
		if y >= multi_map.map_min + (l * multi_map.layer_height)
		   and y < multi_map.map_min + ((l + 1) * multi_map.layer_height)
		then
			multi_map.current_layer = l
		end
	end
end

function multi_map.get_offset_y(y)
	local center_point = multi_map.map_min + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height
	return y - center_point
end

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

function multi_map.register_generator(...)
	local arg = {...}
	local position
	local generator
	local arguments

	if arg[3] then
		position = arg[1]
		generator = arg[2]
		arguments = arg[3]
		print(arguments)
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

local firstrun = true
-- Global helpers for mapgens
multi_map.c_stone = nil
multi_map.c_sandstone = nil
multi_map.c_air = nil
multi_map.c_water = nil
multi_map.c_lava = nil
multi_map.c_bedrock = nil
multi_map.c_skyrock = nil

minetest.register_on_mapgen_init(function(mapgen_params)
	if multi_map.number_of_layers * multi_map.layer_height > multi_map.map_height then
		minetest.log("error", "Number of layers for the given layer height exceeds map height!")
	end
end)

minetest.register_on_generated(function(minp, maxp)
	if firstrun then
		multi_map.c_stone = minetest.get_content_id("default:stone")
		multi_map.c_sandstone = minetest.get_content_id("default:sandstone")
		multi_map.c_air = minetest.get_content_id("air")
		multi_map.c_water = minetest.get_content_id("default:water_source")
		multi_map.c_lava = minetest.get_content_id("default:lava_source")
		multi_map.c_bedrock = minetest.get_content_id(multi_map.bedrock)
		multi_map.c_skyrock = minetest.get_content_id(multi_map.skyrock)
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
		multi_map.map_min + (multi_map.layer_height * multi_map.current_layer) == minp.y
	then
		local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local vm_data = vm:get_data()

		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.c_bedrock)
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

		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.c_skyrock)
		vm:set_lighting({day=15, night=0})
		vm:set_data(vm_data)
		vm:calc_lighting(false)
		vm:write_to_map(false)
	else
		local t = multi_map.generators[multi_map.current_layer]
		if not t then
			if multi_map.fallback_generator then
				multi_map.fallback_generator.generator(multi_map.current_layer, minp, maxp, offset_minp, offset_maxp, multi_map.fallback_generator.arguments)
			else
				minetest.log("error", "Generator for layer "..multi_map.current_layer.." missing and no fallback specified, exiting mapgen!")
				return
			end
		else
			for i,f in ipairs(t) do
				f.generator(multi_map.current_layer, minp, maxp, offset_minp, offset_maxp, f.arguments)
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
