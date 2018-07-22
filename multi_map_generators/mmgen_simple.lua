mmgen_simple = {}

function mmgen_simple.generate(current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp, nodetype)
	local c_ground
	if nodetype then
		c_ground = multi_map.node[nodetype]
	else
		c_ground = multi_map.node["default:stone"]
	end

	if offset_minp.y >= 0 then
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node["air"])
	else
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, c_ground)
	end

end
