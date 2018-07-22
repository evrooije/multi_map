mmgen_testauri = {}
local layers = {}

mmgen_testauri.water_height = 0

multi_map.register_global_2dmap(
	"height_map",
	{
		offset = 0,
		scale = 50,
		spread = {x=2048, y=2048, z=2048},
		seed = 6897925,
		octaves = 7,
		persist = 0.7
	}
)

multi_map.register_global_2dmap(
	"terrain_type",
	{
		offset = 2.5,
		scale = 2.5,
		spread = {x=1024, y=1024, z=1024},
		seed = 9414432,
		octaves = 6,
		persist = 0.6
	}
)

multi_map.register_global_2dmap(
	"mountain_peak",
	{
		offset = -75,
		scale = 125,
		spread = {x=256, y=256, z=256},
		seed = 21341535,
		octaves = 7,
		persist = 0.6
	}
)

mmgen_testauri.cave_seed = 6568239
mmgen_testauri.lake_seed = 6568239

-- Base terrain is the lower frequency, lower amplitude noise
-- Terrain type is a multiplier that can dampen terrain to make
-- flat plains, hills or mountains
-- Mountain peak generates peaks when greater than zero, making
-- jagged and rugged peaks on the surface or mountain tops
local lake_map

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

local lake_params = {
	offset = 0,
	scale = 125,
	spread = {x=256, y=256, z=256},
	seed = mmgen_testauri.lake_seed,
	octaves = 6,
	persist = 0.6
}

local cave_params = {
	offset = 0,
	scale = 10,
	spread = {x=128, y=128, z=128},
	seed = mmgen_testauri.cave_seed,
	octaves = 5,
	persist = 0.8
}

local perlin_worm_start_params = {
	offset = 0,
	scale = 1,
	spread = {x=256, y=256, z=256},
	seed = 9876,
	octaves = 7,
	persist = 0.7
}

function mmgen_testauri.generate(current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp)
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

	cave_map = cave_map or minetest.get_perlin_map(cave_params, chulenxyz)
--	perlin_worm_start_map = perlin_worm_start_map or minetest.get_perlin_map(perlin_worm_start_params, chulenxyz)

	local height_map_2dmap = multi_map.get_global_2dmap_flat("height_map", chulenxz, minposxz)
	local terrain_type_2dmap = multi_map.get_global_2dmap_flat("terrain_type", chulenxz, minposxz)
	local mountain_peak_2dmap = multi_map.get_global_2dmap_flat("mountain_peak", chulenxz, minposxz)

	cave_map:get3dMap_flat(minposxyz, cave_3dmap)
--	perlin_worm_start_map:get3dMap_flat(minposxyz, perlin_worm_start_3dmap)

	-- 3D perlinmap indexes
	local nixyz = 1
	-- 2D perlinmap indexes
	local nixz = 1

--	local worm_started = false

	for z = minp.z, maxp.z do
		local niz
		local oy = offset_minp.y
		for y = minp.y, maxp.y do
			local vi = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				local nix
				local terrain_type = terrain_type_2dmap[nixz]
				local height = terrain_type * height_map_2dmap[nixz]

				if mountain_peak_2dmap[nixz] > 0 then
					height = height + mountain_peak_2dmap[nixz]
				end

				if oy <= height then
					vm_data[vi] = multi_map.node["default:stone"]
				elseif oy <= mmgen_testauri.water_height then
					vm_data[vi] = multi_map.node["default:water_source"]
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
			oy = oy + 1
		end
		nixz = nixz + sidelen
	end

end
