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

	if pos.x < -30912 + 240 then
		return multi_map.world_edge.NEGATIVE_X
	elseif pos.x > 30927 - 240 then
		return multi_map.world_edge.POSITIVE_X
	elseif pos.y < -30912 + 240 then
		return multi_map.world_edge.NEGATIVE_Z
	elseif pos.y > 30927 - 240 then
		return multi_map.world_edge.POSITIVE_Z
	else
		return nil
	end

end

function multi_map.in_mixing_area(pos)
	if  pos.x > 30927 - 240 or pos.y > 30927 - 240 then
		return true
	else
		return false
	end
end

function multi_map.in_mirrored_area_1(pos)
	if  pos.x > 30927 - 160 or pos.y > 30927 - 160 then
		return true
	else
		return false
	end
end

function multi_map.in_mirrored_area_2(pos)
	if  pos.x > 30927 - 80 or pos.y > 30927 - 80 then
		return true
	else
		return false
	end
end

function multi_map.in_skip_area(pos)
	if  pos.x < -30912 + 80 or pos.y < -30912 + 80 then
		return true
	else
		return false
	end
end

-- Normal area         Mixed area                           Mirrored area                                                           Teleport area
-- layer 1a (-320) --> layer mixed 1b (-240) and 2a (0) --> layer 1 supressed (-160) layer 2b mirrored (80) --> teleport --> layer 1 supressed (-80) layer 2c mirrored (160)
-- Normal area          Normal area                           Normal area
-- layer 2a (0) air --> layer 2b (80) --> teleport --> layer 2c (160)
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

	if multi_map.in_mirrored_area_2(minposxz) then
		if multi_map.world_edge.POSITIVE_X == edge then
			opposite_minposxz.x = -30912 + 160
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			opposite_minposxz.y = -30912 + 160
		end

		local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
		local map2 = noise2:get2dMap_flat(opposite_minposxz)

		return map2

	elseif multi_map.in_mirrored_area_1(minposxz) then
		if multi_map.world_edge.POSITIVE_X == edge then
			opposite_minposxz.x = -30912 + 80
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			opposite_minposxz.y = -30912 + 80
		end
		
		local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
		local map2 = noise2:get2dMap_flat(opposite_minposxz)

		return map2

	elseif multi_map.in_mixing_area(minposxz) then
		if multi_map.world_edge.POSITIVE_X == edge then
			opposite_minposxz.x = -30912
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			opposite_minposxz.y = -30912
		end

		if multi_map.world_edge.NEGATIVE_X == edge then
			local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
			local map2 = noise2:get2dMap_flat(opposite_minposxz)
			return map2
		elseif multi_map.world_edge.POSITIVE_X == edge then
			local noise1 = minetest.get_perlin_map(multi_map.global_2d_params[name][layer], chulenxz)
			local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
			local map1 = noise1:get2dMap_flat(minposxz)
			local map2 = noise2:get2dMap_flat(opposite_minposxz)
			return multi_map.mix_noise_map_x(map1, map2, minposxz)
		elseif multi_map.world_edge.NEGATIVE_Z == edge then
			local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
			local map2 = noise2:get2dMap_flat(opposite_minposxz)
			return map2
		elseif multi_map.world_edge.POSITIVE_Z == edge then
			local noise1 = minetest.get_perlin_map(multi_map.global_2d_params[name][layer], chulenxz)
			local noise2 = minetest.get_perlin_map(multi_map.global_2d_params[name][target_layer], chulenxz)
			local map1 = noise1:get2dMap_flat(minposxz)
			local map2 = noise2:get2dMap_flat(opposite_minposxz)
			return multi_map.mix_noise_map_z(map2, map1, minposxz)
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

	local weight_index = 79
	for y = minposxz.y, minposxz.y + 79 do
		for x = minposxz.x, minposxz.x + 79 do
			new_map[nixz] = ( map1[nixz] * (1 - (weight_index / 80)) ) + ( map2[nixz] * (weight_index / 80) )
			nixz = nixz + 1
		end
		weight_index = weight_index - 1
	end

	return new_map

end

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 1 then
		for _,player in ipairs(minetest.get_connected_players()) do
			local posxz = { x = player:get_pos().x, y = player:get_pos().z }
			local edge = multi_map.get_which_world_edge(posxz)
			if edge then
				local layer = multi_map.get_layer(player:get_pos().y)
				local target_layer = multi_map.get_linked_layer(layer, edge)
				if target_layer then
					if posxz.x > 30927 - 79 then
						local ydiff = (target_layer - layer) * multi_map.layer_height
						player:set_pos({ x = 240 + posxz.x - 61840, y = player:get_pos().y + ydiff, z = player:get_pos().z })
					end
					if posxz.x < -30912 + 160 then
						local ydiff = (target_layer - layer) * multi_map.layer_height
						player:set_pos({ x = -240 + posxz.x + 61840, y = player:get_pos().y + ydiff, z = player:get_pos().z })
					end
					if posxz.y > 30927 - 79 then
						local ydiff = (target_layer - layer) * multi_map.layer_height
						player:set_pos({ x = player:get_pos().x, y = player:get_pos().y + ydiff, z = 240 + posxz.y - 61840 })
					end
					if posxz.y < -30912 + 160 then
						local ydiff = (target_layer - layer) * multi_map.layer_height
						player:set_pos({ x = player:get_pos().x, y = player:get_pos().y + ydiff, z = -240 + posxz.y + 61840 })
					end
				end
			end
		end
		timer = 0
	end
end)
