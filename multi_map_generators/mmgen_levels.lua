mmgen_levels = {}

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

multi_map.register_global_3dmap(
	"terrain", {
		offset = 0,
		scale = 1,
		spread = {x=384, y=192, z=384},
		seed = 5900033,
		octaves = 5,
		persist = 0.63,
		lacunarity = 2.0,
	}
)

-- 2D noise

multi_map.register_global_2dmap(
	"spike", {
		offset = 0,
		scale = 1,
		spread = {x=128, y=128, z=128},
		seed = -188900,
		octaves = 3,
		persist = 0.5,
		lacunarity = 2.0,
		flags = "noeased"
	}
)

-- Nodes
 
minetest.register_node("multi_map_generators:grass", {
	description = "Grass",
	tiles = {"default_grass.png", "default_dirt.png", "default_grass.png"},
	groups = {crumbly=3},
	sounds = default.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.25},
	}),
})

minetest.register_node("multi_map_generators:dirt", {
	description = "Dirt",
	tiles = {"default_dirt.png"},
	groups = {crumbly=3},
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_node("multi_map_generators:luxore", {
	description = "Lux Ore",
	tiles = {"levels_luxore.png"},
	paramtype = "light",
	light_source = 14,
	groups = {cracky=3},
	sounds = default.node_sound_glass_defaults(),
})
 
-- Stuff

local floatper = math.pi / FLOATPER

-- Generate function

function mmgen_levels.generate(current_layer, vm, area, data, minp, maxp, offset_minp, offset_maxp, params)

	if not params then params = {} end

	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	local oy1 = offset_maxp.y
	local oy0 = offset_minp.y
	
	local c_stone = minetest.get_content_id("default:stone")
	local c_sand  = minetest.get_content_id("default:sand")
	local c_water = minetest.get_content_id("default:water_source")
	local c_lava  = minetest.get_content_id("default:lava_source")
	
	local c_grass  = minetest.get_content_id("multi_map_generators:grass")
	local c_dirt   = minetest.get_content_id("multi_map_generators:dirt")
	local c_luxore = minetest.get_content_id("multi_map_generators:luxore")

	local sidelen = x1 - x0 + 1
	local ystride = sidelen + 32
	--local zstride = ystride ^ 2
	local chulens3d = {x=sidelen, y=sidelen+17, z=sidelen}
	local chulens2d = {x=sidelen, y=sidelen, z=1}
	local minpos3d = {x=x0, y=y0-16, z=z0}
	local minpos2d = {x=x0, y=z0}
	
	local nvals_terrain = multi_map.get_global_3dmap_flat("terrain", chulens3d, minpos3d)
	local nvals_spike = multi_map.get_global_2dmap_flat("spike", chulens2d, minpos2d)

	local ni3d = 1
	local ni2d = 1
	local stable = {}
	local under = {}
	for z = z0, z1 do
		for x = x0, x1 do
			local si = x - x0 + 1
			stable[si] = 0
		end

		local relative_y = oy0 - 16

		for y = y0 - 16, y1 + 1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				local si = x - x0 + 1
				local viu = vi - ystride

				local n_terrain = nvals_terrain[ni3d]
				local n_spike = nvals_spike[ni2d]
				local spikeoff = 0
				if n_spike > (params.tspike or TSPIKE) then
					spikeoff = (n_spike - (params.tspike or TSPIKE)) ^ 4 * (params.spikeamp or SPIKEAMP)
				end
				local grad = ((params.ysurfcen or YSURFCEN) - relative_y) / (params.tersca or TERSCA) + spikeoff
				if relative_y > (params.ysurfmax or YSURFMAX) then
					grad = math.max(
						(-1 * (params.floatfac or FLOATFAC)) * math.abs(math.cos((relative_y - (params.ysurfmax or YSURFMAX)) * floatper)),
						grad
					)
				elseif relative_y < (params.ysurfmin or YSURFMIN) then
					grad = math.min(
						(params.underfac or UNDERFAC) * (relative_y - (params.yundercen or YUNDERCEN)) ^ 2 + (params.underoff or UNDEROFF),
						grad
					)
				end
				local density = n_terrain + grad

				if y < y0 then
					if density >= (params.tstone or TSTONE) then
						stable[si] = stable[si] + 1
					elseif density <= 0 then
						stable[si] = 0
					end
					if y == y0 - 1 then
						local nodid = data[vi]
						if nodid == c_stone
						or nodid == c_sand
						or nodid == c_grass
						or nodid == c_dirt
						or nodid == c_luxore then
							stable[si] = STABLE
						end
					end
				elseif y >= y0 and y <= y1 then
					if density >= (params.tstone or TSTONE) then
						if math.random() < (params.luxcha or LUXCHA) and relative_y < (params.ysurfmin or YSURFMIN)
						and density < 0.01 and data[viu] == c_stone then
							data[vi] = c_luxore
						else
							data[vi] = c_stone
						end
						stable[si] = stable[si] + 1
						under[si] = 0
					elseif density > 0 and density < (params.tstone or TSTONE)
					and stable[si] >= (params.stable or STABLE) and relative_y > (params.ysurfmin or YSURFMIN) then
						if relative_y <= (params.ysand or YSAND) then
							data[vi] = c_sand
							under[si] = 0
						else
							data[vi] = c_dirt
							under[si] = 1
						end
					elseif relative_y > (params.ysurfmin or YSURFMIN) and relative_y <= (params.ywater or YWATER) then
						data[vi] = c_water
						stable[si] = 0
						under[si] = 0
					elseif relative_y <= (params.ylava or YLAVA) then
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
				elseif y == y1 + 1 then
					if density <= 0 and relative_y > (params.ywater or YWATER) then -- air, possibly just above surface
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
			relative_y = relative_y + 1
		end
		ni2d = ni2d + sidelen
	end

end
