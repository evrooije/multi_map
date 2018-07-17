-- levels 0.2.6
-- bugfixes: rename luxoff to luxore, remove 'local' from nobj_s

-- Parameters

local TERSCA = 96
local TSPIKE = 1.2
local SPIKEAMP = 2000
local TSTONE = 0.04
local STABLE = 2

local FLOATPER = 512
local FLOATFAC = 2
local FLOATOFF = -0.2

local YSURFMAX = 256
local YSAND = 4
local YWATER = 1
local YSURFCEN = 0
local YSURFMIN = -256

local YUNDERCEN = -512
local YLAVA = -528
local UNDERFAC = 0.0001
local UNDEROFF = -0.2
local LUXCHA = 1 / 9 ^ 3

-- Noise parameters

-- 3D noise

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=384, y=192, z=384},
	seed = 5900033,
	octaves = 5,
	persist = 0.63,
	lacunarity = 2.0,
	--flags = ""
}

-- 2D noise

local np_spike = {
	offset = 0,
	scale = 1,
	spread = {x=128, y=128, z=128},
	seed = -188900,
	octaves = 3,
	persist = 0.5,
	lacunarity = 2.0,
	flags = "noeased"
}

-- Nodes
 
minetest.register_node("mm_testauri_mountains:grass", {
	description = "Grass",
	tiles = {"default_grass.png", "default_dirt.png", "default_grass.png"},
	groups = {crumbly=3},
	sounds = default.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.25},
	}),
})

minetest.register_node("mm_testauri_mountains:dirt", {
	description = "Dirt",
	tiles = {"default_dirt.png"},
	groups = {crumbly=3},
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_node("mm_testauri_mountains:luxore", {
	description = "Lux Ore",
	tiles = {"levels_luxore.png"},
	paramtype = "light",
	light_source = 14,
	groups = {cracky=3},
	sounds = default.node_sound_glass_defaults(),
})
 
-- Stuff

local floatper = math.pi / FLOATPER

-- Set mapgen parameters

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode", flags="nolight"})
end)

-- Initialize noise objects to nil

local nobj_terrain = nil
local nobj_spike = nil

-- On generated function

function generate(current_layer, minp, maxp, offset_minp, offset_maxp)
--	local t0 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	local ox1 = offset_maxp.x
	local oy1 = offset_maxp.y
	local oz1 = offset_maxp.z
	local ox0 = offset_minp.x
	local oy0 = offset_minp.y
	local oz0 = offset_minp.z
--	print ("[levels] chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_stone = minetest.get_content_id("default:stone")
	local c_sand  = minetest.get_content_id("default:sand")
	local c_water = minetest.get_content_id("default:water_source")
	local c_lava  = minetest.get_content_id("default:lava_source")
	
	local c_grass  = minetest.get_content_id("mm_testauri_mountains:grass")
	local c_dirt   = minetest.get_content_id("mm_testauri_mountains:dirt")
	local c_luxore = minetest.get_content_id("mm_testauri_mountains:luxore")

	local sidelen = x1 - x0 + 1
	local ystride = sidelen + 32
	--local zstride = ystride ^ 2
	local chulens3d = {x=sidelen, y=sidelen+17, z=sidelen}
	local chulens2d = {x=sidelen, y=sidelen, z=1}
	local minpos3d = {x=x0, y=y0-16, z=z0}
	local minpos2d = {x=x0, y=z0}
	
	nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, chulens3d)
	nobj_spike = nobj_spike or minetest.get_perlin_map(np_spike, chulens2d)
	
	local nvals_terrain = nobj_terrain:get3dMap_flat(minpos3d)
	local nvals_spike = nobj_spike:get2dMap_flat(minpos2d)

	local ni3d = 1
	local ni2d = 1
	local stable = {}
	local under = {}
	for z = oz0, oz1 do
		for x = ox0, ox1 do
			local si = x - ox0 + 1
			stable[si] = 0
		end
		for y = oy0 - 16, oy1 + 1 do
			local vi = area:index(x0, y, z)
			for x = ox0, ox1 do
				local si = x - ox0 + 1
				local viu = vi - ystride

				local n_terrain = nvals_terrain[ni3d]
				local n_spike = nvals_spike[ni2d]
				local spikeoff = 0
				if n_spike > TSPIKE then
					spikeoff = (n_spike - TSPIKE) ^ 4 * SPIKEAMP
				end
				local grad = (YSURFCEN - y) / TERSCA + spikeoff
				if y > YSURFMAX then
					grad = math.max(
						-FLOATFAC * math.abs(math.cos((y - YSURFMAX) * floatper)),
						grad
					)
				elseif y < YSURFMIN then
					grad = math.min(
						UNDERFAC * (y - YUNDERCEN) ^ 2 + UNDEROFF,
						grad
					)
				end
				local density = n_terrain + grad

				if y < oy0 then
					if density >= TSTONE then
						stable[si] = stable[si] + 1
					elseif density <= 0 then
						stable[si] = 0
					end
					if y == oy0 - 1 then
						local nodid = data[vi]
						if nodid == c_stone
						or nodid == c_sand
						or nodid == c_grass
						or nodid == c_dirt
						or nodid == c_luxore then
							stable[si] = STABLE
						end
					end
				elseif y >= oy0 and y <= oy1 then
					if density >= TSTONE then
						if math.random() < LUXCHA and y < YSURFMIN
						and density < 0.01 and data[viu] == c_stone then
							data[vi] = c_luxore
						else
							data[vi] = c_stone
						end
						stable[si] = stable[si] + 1
						under[si] = 0
					elseif density > 0 and density < TSTONE
					and stable[si] >= STABLE and y > YSURFMIN then
						if y <= YSAND then
							data[vi] = c_sand
							under[si] = 0
						else
							data[vi] = c_dirt
							under[si] = 1
						end
					elseif y > YSURFMIN and y <= YWATER then
						data[vi] = c_water
						stable[si] = 0
						under[si] = 0
					elseif y <= YLAVA then
						data[vi] = c_lava
						stable[si] = 0
						under[si] = 0
					else -- air, possibly just above surface
						if under[si] == 1 then
							data[viu] = c_grass
						end
						stable[si] = 0
						under[si] = 0
					end
				elseif y == oy1 + 1 then
					if density <= 0 and y > YWATER then -- air, possibly just above surface
						if under[si] == 1 then
							data[viu] = c_grass
						end
					end
				end

				ni3d = ni3d + 1
				ni2d = ni2d + 1
				vi = vi + 1
			end
			ni2d = ni2d - sidelen
		end
		ni2d = ni2d + sidelen
	end
	
	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map(data)
	vm:update_liquids()

--	local chugent = math.ceil((os.clock() - t0) * 1000)
--	print ("[levels] "..chugent.." ms")
end
