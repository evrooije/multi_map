multi_map.world_edge = {
	NEGATIVE_X = 1,
	POSITIVE_X = 2,
	NEGATIVE_Z = 3,
	POSITIVE_Z = 4,
}

multi_map.linked_layers = {}

function multi_map.register_linked_layer(source_layer, edge, target_layer, link_back)
	if not multi_map.linked_layers[source_layer] then
		multi_map.linked_layers[source_layer] = {}
	end

	if not multi_map.linked_layers[target_layer] then
		multi_map.linked_layers[target_layer] = {}
	end

	if link_back == nil then
		link_back = true
	end

	if multi_map.world_edge.NEGATIVE_X == edge then
		multi_map.linked_layers[source_layer][multi_map.world_edge.NEGATIVE_X] = target_layer
		if link_back then
			multi_map.linked_layers[target_layer][multi_map.world_edge.POSITIVE_X] = source_layer
		end
	elseif multi_map.world_edge.POSITIVE_X == edge then
		multi_map.linked_layers[source_layer][multi_map.world_edge.POSITIVE_X] = target_layer
		if link_back then
			multi_map.linked_layers[target_layer][multi_map.world_edge.NEGATIVE_X] = source_layer
		end
	elseif multi_map.world_edge.NEGATIVE_Z == edge then
		multi_map.linked_layers[source_layer][multi_map.world_edge.NEGATIVE_Z] = target_layer
		if link_back then
			multi_map.linked_layers[target_layer][multi_map.world_edge.POSITIVE_Z] = source_layer
		end
	elseif multi_map.world_edge.POSITIVE_Z == edge then
		multi_map.linked_layers[source_layer][multi_map.world_edge.POSITIVE_Z] = target_layer
		if link_back then
			multi_map.linked_layers[target_layer][multi_map.world_edge.NEGATIVE_Z] = source_layer
		end
	end
	
end

function multi_map.get_linked_layer(layer, edge)
	if multi_map.linked_layers[layer] then
		return multi_map.linked_layers[layer][edge]
	end
end

function multi_map.get_which_world_edge(pos)

	if pos.x < -30912 + 160 then
		return multi_map.world_edge.NEGATIVE_X
	elseif pos.x > 30927 - 160 then
		return multi_map.world_edge.POSITIVE_X
	elseif pos.y < -30912 + 160 then
		return multi_map.world_edge.NEGATIVE_Z
	elseif pos.y > 30927 - 160 then
		return multi_map.world_edge.POSITIVE_Z
	else
		return nil
	end

end

function multi_map.in_mixing_area(pos)
	if  pos.x < -30912 + 160 or pos.x > 30927 - 160 or
		pos.y < -30912 + 160 or pos.y > 30927 - 160 then
		return true
	else
		return false
	end
end

function multi_map.in_mirrored_area(pos)
	if  pos.x < -30912 + 80 or pos.x > 30927 - 80 or
		pos.y < -30912 + 80 or pos.y > 30927 - 80 then
		return true
	else
		return false
	end
end

-- Current
-- 160      80
-- [     ]  [     ]
-- [  L  ]  [  M  ]
-- [     ]  [     ]
-- Opposite
-- 0        80
-- [     ]  [     ]
-- [  L  ]  [  M  ]
-- [     ]  [     ]
function multi_map.get_mixed_2dnoise_flat(name, chulenxz, minposxz, layer)
	local edge = multi_map.get_which_world_edge(minposxz)
	
	if edge == nil then
		return
	end
	
	local target_layer = multi_map.get_linked_layer(layer, edge)

	if not target_layer then
		return nil
	end

	local opposite_minposxz = { x = minposxz.x, y = minposxz.y }

	if multi_map.in_mirrored_area(minposxz) then
		if multi_map.world_edge.NEGATIVE_X == edge then
			opposite_minposxz.x = 30927 - 160
		elseif multi_map.world_edge.POSITIVE_X == edge then
			opposite_minposxz.x = -30912 + 160
		elseif multi_map.world_edge.NEGATIVE_Z == edge then
			opposite_minposxz.y = 30927 - 160
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			opposite_minposxz.y = -30912 + 160
		end
		
		local noise1 = minetest.get_perlin_map(multi_map.global_2d_params[name][layer], chulenxz)
		local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
		local map1 = noise1:get2dMap_flat(minposxz)
		local map2 = noise2:get2dMap_flat(opposite_minposxz)

		if multi_map.world_edge.NEGATIVE_X == edge then
			return multi_map.mix_noise_map_x(map1, map2, opposite_minposxz)
		elseif multi_map.world_edge.POSITIVE_X == edge then
			return multi_map.mix_noise_map_x(map2, map1, opposite_minposxz)
		elseif multi_map.world_edge.NEGATIVE_Z == edge then
			return multi_map.mix_noise_map_z(map1, map2, opposite_minposxz)
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			return multi_map.mix_noise_map_x(map2, map1, opposite_minposxz)
		end

	elseif multi_map.in_mixing_area(minposxz) then
		if multi_map.world_edge.NEGATIVE_X == edge then
			opposite_minposxz.x = 30927 - 80
		elseif multi_map.world_edge.POSITIVE_X == edge then
			opposite_minposxz.x = -30912 + 80
		elseif multi_map.world_edge.NEGATIVE_Z == edge then
			opposite_minposxz.y = 30927 - 80
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			opposite_minposxz.y = -30912 + 80
		end

		local noise1 = minetest.get_perlin_map(multi_map.global_2d_params[name][layer], chulenxz)
		local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
		local map1 = noise1:get2dMap_flat(minposxz)
		local map2 = noise2:get2dMap_flat(opposite_minposxz)

		if multi_map.world_edge.NEGATIVE_X == edge then
			return multi_map.mix_noise_map_x(map2, map1, minposxz)
		elseif multi_map.world_edge.POSITIVE_X == edge then
			return multi_map.mix_noise_map_x(map1, map2, minposxz)
		elseif multi_map.world_edge.NEGATIVE_Z == edge then
			return multi_map.mix_noise_map_z(map2, map1, minposxz)
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			return multi_map.mix_noise_map_x(map1, map2, minposxz)
		end
	else
		return nil
	end
	
end

function multi_map.mix_noise_map_x(map1, map2, minposxz)

	local new_map = {}
	local nixz = 1

	for y = minposxz.y, minposxz.y + 79 do
		local weight_index = 1
		for x = minposxz.x, minposxz.x + 79 do
			new_map[nixz] = ( map1[nixz] * (1 - (weight_index / 80)) ) + ( map2[nixz] * (weight_index / 80) )
			nixz = nixz + 1
			weight_index = weight_index + 1
		end
	end

	return new_map

end

function multi_map.mix_noise_map_z(map1, map2, minposxz)

	local new_map = {}
	local nixz = 1

	for y = minposxz.y, minposxz.y + 80 do
		local weight_index = 1
		for x = minposxz.x, minposxz.x + 80 do
			new_map[nixz] = ( map1[nixz] * (1 - (weight_index / 160)) ) + ( map2[nixz] * (weight_index / 160) )
			nixz = nixz + 1
		end
		weight_index = weight_index + 1
		nixz = nixz - 80
	end

	return new_map

end
