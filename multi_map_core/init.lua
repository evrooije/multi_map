multi_map = {}

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

-- Get the offset y position, i.e. the y relative to the current layer's center point
-- y = absolute y value to be translated to y relative to layer center point
function multi_map.get_offset_y(y)
	local center_point = multi_map.map_min + (multi_map.current_layer * multi_map.layer_height) + multi_map.half_layer_height

	if center_point > 0 and y > 0 then
		return math.abs(y) - math.abs(center_point)
	elseif center_point < 0 and y < 0 then
		return math.abs(center_point) - math.abs(y)
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

local firstrun = true
-- Global helpers for mapgens
multi_map.c_ignore = nil
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
	minetest.set_mapgen_params({mgname="singlenode", flags="nolight"})
end)

minetest.register_on_generated(function(minp, maxp)
	if firstrun then
		multi_map.c_ignore = minetest.get_content_id("ignore")
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




--[[


function multi_map.calc_lighting(emin, emax, pmin, pmax, propagate_shadow, ground_level)
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	multi_map.propagate_sunlight(vm, emin, emax, propagate_shadow, ground_level)
	spread_light(pmin, pmax)
}


function multi_map.propagate_sunlight(vm, emin, emax, propagate_shadow, ground_level)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local vm_data = vm:get_data()
	local light_data = vm:get_light_data()

	-- const v3s16 &em = vm->m_area.getExtent();

	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local vi = area:index(x, emax.y + 1, z)
			if vm_data[vi] == multi_map.c_ignore then
				if block_is_underground then
					goto continue
				end
			elseif (light_data[vi] & 15) ~= 15 and propagate_shadow then
				goto continue
			end
			vi = vi + 1
			::continue::
		end
	end


	VoxelArea a(nmin, nmax);
	bool block_is_underground = (water_level >= nmax.Y);
	const v3s16 &em = vm->m_area.getExtent();

	// NOTE: Direct access to the low 4 bits of param1 is okay here because,
	// by definition, sunlight will never be in the night lightbank.

	for (int z = a.MinEdge.Z; z <= a.MaxEdge.Z; z++) {
		for (int x = a.MinEdge.X; x <= a.MaxEdge.X; x++) {
			// see if we can get a light value from the overtop
			u32 i = vm->m_area.index(x, a.MaxEdge.Y + 1, z);
			if (vm->m_data[i].getContent() == CONTENT_IGNORE) {
				if (block_is_underground)
					continue;
			} else if ((vm->m_data[i].param1 & 0x0F) != LIGHT_SUN &&
					propagate_shadow) {
				continue;
			}
			VoxelArea::add_y(em, i, -1);

			for (int y = a.MaxEdge.Y; y >= a.MinEdge.Y; y--) {
				MapNode &n = vm->m_data[i];
				if (!ndef->get(n).sunlight_propagates)
					break;
				n.param1 = LIGHT_SUN;
				VoxelArea::add_y(em, i, -1);
			}
		}
	}
	//printf("propagateSunlight: %dms\n", t.stop());
}

void Mapgen::spreadLight(v3s16 nmin, v3s16 nmax)
{
	//TimeTaker t("spreadLight");
	VoxelArea a(nmin, nmax);

	for (int z = a.MinEdge.Z; z <= a.MaxEdge.Z; z++) {
		for (int y = a.MinEdge.Y; y <= a.MaxEdge.Y; y++) {
			u32 i = vm->m_area.index(a.MinEdge.X, y, z);
			for (int x = a.MinEdge.X; x <= a.MaxEdge.X; x++, i++) {
				MapNode &n = vm->m_data[i];
				if (n.getContent() == CONTENT_IGNORE)
					continue;

				const ContentFeatures &cf = ndef->get(n);
				if (!cf.light_propagates)
					continue;

				// TODO(hmmmmm): Abstract away direct param1 accesses with a
				// wrapper, but something lighter than MapNode::get/setLight

				u8 light_produced = cf.light_source;
				if (light_produced)
					n.param1 = light_produced | (light_produced << 4);

				u8 light = n.param1;
				if (light) {
					lightSpread(a, v3s16(x,     y,     z + 1), light);
					lightSpread(a, v3s16(x,     y + 1, z    ), light);
					lightSpread(a, v3s16(x + 1, y,     z    ), light);
					lightSpread(a, v3s16(x,     y,     z - 1), light);
					lightSpread(a, v3s16(x,     y - 1, z    ), light);
					lightSpread(a, v3s16(x - 1, y,     z    ), light);
				}
			}
		}
	}

	//printf("spreadLight: %dms\n", t.stop());
}



function multi_map.light_spread(area, v3s16 p, u8 light)
{
	if (light <= 1 || !a.contains(p))
		return;

	u32 vi = vm->m_area.index(p);
	MapNode &n = vm->m_data[vi];

	// Decay light in each of the banks separately
	u8 light_day = light & 0x0F;
	if (light_day > 0)
		light_day -= 0x01;

	u8 light_night = light & 0xF0;
	if (light_night > 0)
		light_night -= 0x10;

	// Bail out only if we have no more light from either bank to propogate, or
	// we hit a solid block that light cannot pass through.
	if ((light_day  <= (n.param1 & 0x0F) &&
		light_night <= (n.param1 & 0xF0)) ||
		!ndef->get(n).light_propagates)
		return;

	// Since this recursive function only terminates when there is no light from
	// either bank left, we need to take the max of both banks into account for
	// the case where spreading has stopped for one light bank but not the other.
	light = MYMAX(light_day, n.param1 & 0x0F) |
			MYMAX(light_night, n.param1 & 0xF0);

	n.param1 = light;

	lightSpread(a, p + v3s16(0, 0, 1), light);
	lightSpread(a, p + v3s16(0, 1, 0), light);
	lightSpread(a, p + v3s16(1, 0, 0), light);
	lightSpread(a, p - v3s16(0, 0, 1), light);
	lightSpread(a, p - v3s16(0, 1, 0), light);
	lightSpread(a, p - v3s16(1, 0, 0), light);
}





]]--