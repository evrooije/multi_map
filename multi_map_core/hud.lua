local saved_huds = {}

multi_map.hud = {}

multi_map.hud.enabled = true
multi_map.hud.update_time = 0.25

multi_map.hud.alignment = { x = -1, y = -1 }
multi_map.hud.position = {x = 0.98, y = 0.98}
multi_map.hud.color = 0xFFFFFF

multi_map.hud.display_coordinates = true
multi_map.hud.display_layer = true
multi_map.hud.display_layer_name = true
multi_map.hud.layer_label = "Zone"

minetest.register_on_joinplayer(function(player)
	if multi_map.hud.enabled then
		multi_map.update_hud(player)
	end
end)

minetest.register_on_leaveplayer(function(player)
	if multi_map.hud.enabled and player_huds[player:get_player_name()] then
		player_huds[player:get_player_name()] = nil
	end
end)

function multi_map.update_hud(player)
	if not multi_map.hud.enabled then
		return
	end

	local player_name = player:get_player_name()

	local layer = multi_map.get_layer(player:get_pos().y)
	local offset_y = multi_map.get_offset_y(player:get_pos().y, layer)

	local hud_text = ""

	if multi_map.hud.display_layer or multi_map.hud.display_layer_name then
		hud_text = hud_text..multi_map.hud.layer_label

		if multi_map.hud.display_layer then
			hud_text = hud_text.." "..layer
		end

		local layer_name = multi_map.get_layer_name(layer)
		if multi_map.hud.display_layer_name and layer_name then
			hud_text = hud_text..": "..layer_name
		end

		hud_text = hud_text.."; "
	end

	if multi_map.hud.display_coordinates then
		hud_text = hud_text..string.format("%i, %i, %i", math.floor(player:get_pos().x),
										   math.floor(offset_y), math.floor(player:get_pos().z))
	end

	local ids = saved_huds[player_name]
	if ids then
		player:hud_change(ids["multi_map_hud"], "text", hud_text)
	else
		ids = {}
		saved_huds[player_name] = ids
		
		ids["multi_map_hud"] = player:hud_add({
			hud_elem_type = "text",
			text = hud_text,
			position = multi_map.hud.position,
			alignment = multi_map.hud.alignment,
			number = multi_map.hud.color,
		})

	end
end

local timer = 0
minetest.register_globalstep(function(dtime)
	if multi_map.hud.enabled then
		timer = timer + dtime;
		if timer >= multi_map.hud.update_time then
			for _,player in ipairs(minetest.get_connected_players()) do
				multi_map.update_hud(player)
			end
			timer = 0
		end
	end
end)
