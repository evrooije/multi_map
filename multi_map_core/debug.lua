-- Dump the current state of the multiple map layer generator, i.e. settings, registered generators,
-- registered noises
function multi_map.log_state()
	minetest.log("action", "[multi_map] Multiple map layer generator global settings")
	minetest.log("action", "[multi_map]  - Number of layers: "..multi_map.number_of_layers)
	minetest.log("action", "[multi_map]  - Layers start at: "..(multi_map.map_min + multi_map.layers_start))
	minetest.log("action", "[multi_map]  - Layer height: "..multi_map.layer_height)
	minetest.log("action", "[multi_map]  - Wrap layers: "..tostring(multi_map.wrap_layers))
	minetest.log("action", "[multi_map]  - HUD enabled: "..tostring(multi_map.hud.enabled))

	minetest.log("action", "[multi_map]")
	minetest.log("action", "[multi_map] Registered generators")
	if multi_map.fallback_generator then
		local name = multi_map.fallback_generator.name
		if name then
			name = "\""..name.."\","
		else
			name = ""
		end
		minetest.log("action", "[multi_map]  - "..name.." "..debug.getinfo(multi_map.fallback_generator.generator).short_src:match("^.+/(.+)$").." (fallback)")
	end
	for k,v in pairs(multi_map.generators) do
		local name = multi_map.layer_names[k]
		if name then
			name = "\""..name.."\","
		else
			name = ""
		end
		for l,b in pairs(multi_map.generators[k]) do
			minetest.log("action", "[multi_map]  - "..name.." "..debug.getinfo(b.generator).short_src:match("^.+/(.+)$").." (layer "..k..")")
		end
	end

	minetest.log("action", "[multi_map]")
	minetest.log("action", "[multi_map] Registered global maps")
	for k,v in pairs(multi_map.global_2d_params) do
		minetest.log("action", "[multi_map]  - "..k.." (2D)")
	end
	for k,v in pairs(multi_map.global_3d_params) do
		minetest.log("action", "[multi_map]  - "..k.." (3D)")
	end

	minetest.log("action", "[multi_map]")
end
