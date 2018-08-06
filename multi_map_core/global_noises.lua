-- Mmmmh, might make these local ...
multi_map.global_2d_maps = {}
multi_map.global_2d_params = {}
multi_map.global_2d_map_arrays = {}

multi_map.map_cache = {}

-- Register a named map for use as 2D map. A 3D map could potentially be
-- registered using this as well, but since this is specialized for
-- multiple different seeds per layer, multi_map provides this mechanism.
-- Note: The seed provided in the params is used to seed math.random
-- and each layer gets a randomized seed after that. As such, the noise
-- is still predictable/ reproducible
-- name = the name of the map
-- params = the noise parameters as per minetest standard
function multi_map.register_global_2dmap(name, params)
	if multi_map.global_3d_params[name] or multi_map.global_2d_params[name] then
		minetest.log("error", "[multi_map] Trying to register map "..name..", but it already exists. Aborting registration.")
		return
	end
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
			persist = params.persist,
			lacunarity = params.lacunarity,
			flags = params.flags,
		}
		multi_map.global_2d_params[name][i] = new_params
	end
end

-- Get the named 2D map as flat array
-- name = name of the noise map
-- chulenxz = chunk length in 2 dimensions (xz)
-- minposxz = minimum 2D position (xz)
-- current layer = the layer for which to retrieve the map or nil to use multi_map's current layer
function multi_map.get_global_2dmap_flat(name, chulenxz, minposxz, layer)
	if not multi_map.global_2d_map_arrays[name] then
		minetest.log("error", "[multi_map] Trying to get an unregistered global 2D map")
	end

	if multi_map.wrap_layers then
		if layer then
			multi_map.map_cache[name] = multi_map.get_mixed_2dnoise_flat(name, chulenxz, minposxz, layer)
		else
			multi_map.map_cache[name] = multi_map.get_mixed_2dnoise_flat(name, chulenxz, minposxz, multi_map.current_layer)
		end
	end

	if not multi_map.map_cache[name] then
		if not layer then
			if multi_map.current_layer ~= multi_map.last_used_layer then
				multi_map.global_2d_maps[name] = minetest.get_perlin_map(multi_map.global_2d_params[name][multi_map.current_layer], chulenxz)
			end
			multi_map.map_cache[name] = multi_map.global_2d_maps[name]:get2dMap_flat(minposxz, multi_map.global_2d_map_arrays[name][multi_map.current_layer])
		else
			if layer ~= multi_map.last_used_layer then
				multi_map.global_2d_maps[name] = minetest.get_perlin_map(multi_map.global_2d_params[name][layer], chulenxz)
			end
			multi_map.map_cache[name] = multi_map.global_2d_maps[name]:get2dMap_flat(minposxz, multi_map.global_2d_map_arrays[name][layer])
		end
	end

	return multi_map.map_cache[name]
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
	if multi_map.global_3d_params[name] or multi_map.global_2d_params[name] then
		minetest.log("error", "[multi_map] Trying to register map "..name..", but it already exists. Aborting registration.")
		return
	end
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

	if not multi_map.map_cache[name] then
		if not multi_map.global_3d_maps[name] then
			multi_map.global_3d_maps[name] = minetest.get_perlin_map(multi_map.global_3d_params[name], chulenxyz)
		end
		multi_map.map_cache[name] = multi_map.global_3d_maps[name]:get3dMap_flat(minposxyz, multi_map.global_3d_map_arrays[name])
	end

	return multi_map.map_cache[name]
end
