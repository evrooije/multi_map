local settings = {}
local layers = {}

settings.number_of_layers = 32
settings.day_light = 15
settings.night_light = 0
settings.bedrock = "default:bedrock"
settings.skyrock = "default:skyrock"

settings.water_height = 0

settings.seed = 835726

math.randomseed(settings.seed)

for i = settings.number_of_layers / -2, settings.number_of_layers / 2 do
	layers[i] = {
		height_map_seed = math.random(-1000000000000, 1000000000000),
		height_map_params = {
		   offset = 0,
		   scale = 50,
		   spread = {x=2048, y=2048, z=2048},
		   seed = settings.height_map_seed,
		   octaves = 7,
		   persist = 0.7
		},
		height_map = nil,
		height_map_2dmap = {},
		terrain_type_seed = math.random(-1000000000000, 1000000000000),
		terrain_type_params = {
		   offset = 2.5,
		   scale = 2.5,
		   spread = {x=1024, y=1024, z=1024},
		   seed = settings.terrain_type_seed,
		   octaves = 6,
		   persist = 0.6
		},
		terrain_type_map = nil,
		terrain_type_2dmap = {},
		mountain_map_seed = math.random(-1000000000000, 1000000000000),
		mountain_peak_params = {
		   offset = -75,
		   scale = 125,
		   spread = {x=256, y=256, z=256},
		   seed = settings.mountain_peak_seed,
		   octaves = 7,
		   persist = 0.6
		},
		mountain_peak_map = nil,
		mountain_peak_2dmap = {},
	}
end

settings.cave_seed = 6568239

local layer_height = 65535 / settings.number_of_layers
local half_layer_height = layer_height / 2

-- Base terrain is the lower frequency, lower amplitude noise
-- Terrain type is a multiplier that can dampen terrain to make
-- flat plains, hills or mountains
-- Mountain peak generates peaks when greater than zero, making
-- jagged and rugged peaks on the surface or mountain tops
--local height_map
--local terrain_type_map
--local mountain_peak_map
local lake_map

--local height_map_2dmap = {}
--local terrain_type_2dmap = {}
--local mountain_peak_2dmap = {}
local lake_3dmap = {}

local cave_map
local perlin_worm_start_map
local perlin_worm_yaw_map
local perlin_worm_pitch_map

local cave_3dmap = {}
local perlin_worm_start_3dmap = {}
local perlin_worm_yaw_3dmap = {}
local perlin_worm_pitch_3dmap = {}

local perlin_worms = {}

--local height_map_params = {
--	offset = 0,
--	scale = 50,
--	spread = {x=2048, y=2048, z=2048},
--	seed = settings.height_map_seed,
--	octaves = 7,
--	persist = 0.7
--}

--local terrain_type_params = {
--	offset = 2.5,
--	scale = 2.5,
--	spread = {x=1024, y=1024, z=1024},
--	seed = settings.terrain_type_seed,
--	octaves = 6,
--	persist = 0.6
--}

--local mountain_peak_params = {
--	offset = -75,
--	scale = 125,
--	spread = {x=256, y=256, z=256},
--	seed = settings.mountain_peak_seed,
--	octaves = 7,
--	persist = 0.6
--}

local lake_params = {
	offset = 0,
	scale = 125,
	spread = {x=256, y=256, z=256},
	seed = settings.lake_seed,
	octaves = 6,
	persist = 0.6
}

local cave_params = {
	offset = 0,
	scale = 10,
	spread = {x=128, y=128, z=128},
	seed = settings.cave_seed,
	octaves = 5,
	persist = 0.8
}

local perlin_worm_start_params = {
	offset = 0,
	scale = 1,
	spread = {x=256, y=256, z=256},
	seed = settings.perlin_worm_start_seed,
	octaves = 7,
	persist = 0.7
}

minetest.register_node("default:skyrock", {
	description = "Multi Map Impenetrable Skyblock",
	drawtype = "airlike",
	tiles ={"star_button.png"},
	inventory_image = "star_button.png",
	is_ground_content = false,
	walkable = true,
	pointable = false,
	diggable = false,
	climbable = false,
})

minetest.register_node("default:bedrock", {
	description = "Multi Map Impenetrable Bedrock",
	drawtype = "normal",
	tiles ={"multi_map_bedrock.png"},
	is_ground_content = false,
	walkable = true,
	pointable = false,
	diggable = false,
	climbable = false,
})

minetest.register_on_generated(function(minp, maxp)
	local c_stone = minetest.get_content_id("default:stone")
	local c_air = minetest.get_content_id("air")
	local c_water = minetest.get_content_id("default:water_source")
	local c_bedrock = minetest.get_content_id("default:bedrock")
	local c_skyrock = minetest.get_content_id("default:skyrock")

	local current_layer = nil

	for l = (settings.number_of_layers / -2), (settings.number_of_layers / 2) do
		if minp.y >= (l * layer_height) - half_layer_height and minp.y < (l * layer_height) + half_layer_height then
			current_layer = l
			break
		end
	end

	if not current_layer then
		minetest.log("error", "Could not determine current multi_map layer, exiting mapgen!")
		return
	end

	local sidelen = maxp.x - minp.x + 1
	local blocklen = sidelen / 5
	--3d
	local chulenxyz = {x = sidelen, y = sidelen, z = sidelen}
	--2d
	local chulenxz = {x = sidelen, y = sidelen, z = 1}

	local minposxyz = {x = minp.x, y = minp.y - 1, z = minp.z}
	local minposxz = {x = minp.x, y = minp.z}

	-- strides for voxelmanip
	local ystridevm = sidelen + 32
	local zstridevm = ystridevm ^ 2

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local vm_data = vm:get_data()

	layers[current_layer].height_map = layers[current_layer].height_map or
									   minetest.get_perlin_map(layers[current_layer].height_map_params, chulenxz)

	layers[current_layer].terrain_type_map = layers[current_layer].terrain_type_map or
											 minetest.get_perlin_map(layers[current_layer].terrain_type_params, chulenxz)

	layers[current_layer].mountain_peak_map = layers[current_layer].mountain_peak_map or
											  minetest.get_perlin_map(layers[current_layer].mountain_peak_params, chulenxz)

	cave_map = cave_map or minetest.get_perlin_map(cave_params, chulenxyz)
	perlin_worm_start_map = perlin_worm_start_map or minetest.get_perlin_map(perlin_worm_start_params, chulenxyz)

	layers[current_layer].height_map:get2dMap_flat(minposxz, layers[current_layer].height_map_2dmap)
	layers[current_layer].terrain_type_map:get2dMap_flat(minposxz, layers[current_layer].terrain_type_2dmap)
	layers[current_layer].mountain_peak_map:get2dMap_flat(minposxz, layers[current_layer].mountain_peak_2dmap)

	cave_map:get3dMap_flat(minposxyz, cave_3dmap)
	perlin_worm_start_map:get3dMap_flat(minposxyz, perlin_worm_start_3dmap)

	-- 3D perlinmap indexes
	local nixyz = 1
	-- 2D perlinmap indexes
	local nixz = 1

	local worm_started = false

	for z = minp.z, maxp.z do
		local niz
		for y = minp.y, maxp.y do
			local vi = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				local nix
				local terrain_type = layers[current_layer].terrain_type_2dmap[nixz]
				local height = terrain_type * layers[current_layer].height_map_2dmap[nixz]

				if layers[current_layer].mountain_peak_2dmap[nixz] > 0 then
					height = height + layers[current_layer].mountain_peak_2dmap[nixz]
				end

				if (layer_height * current_layer) - half_layer_height <= y and y <= (layer_height * current_layer) - half_layer_height + (sidelen / 2) then
					vm_data[vi] = c_bedrock
				elseif (layer_height * current_layer) + half_layer_height - (sidelen * 5) <= y and y <= (layer_height * current_layer) + half_layer_height then
					vm_data[vi] = c_skyrock
				elseif y <= height + (layer_height * current_layer) then
--					if math.abs(cave_3dmap[nixyz]) < 10 then -- + (y / 400) then
						vm_data[vi] = c_stone
--					else
--						vm_data[vi] = c_air
--					end
				elseif y <= (layer_height * current_layer) + settings.water_height then
					vm_data[vi] = c_water
				end

				-- Increment noise index.
				nixyz = nixyz + 1
				nixz = nixz + 1

				-- Increment voxelmanip index along x row.
			 	-- The voxelmanip index increases by 1 when
			 	-- moving by 1 node in the +x direction.
				vi = vi + 1
			end
			nixz = nixz - sidelen
		end
		nixz = nixz + sidelen
	end


	vm:set_data(vm_data)
	vm:set_lighting({day=settings.day_light, night=settings.night_light})
	vm:update_liquids()
	vm:calc_lighting(false)
	vm:write_to_map()
end)
