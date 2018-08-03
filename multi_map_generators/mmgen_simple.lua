mmgen_simple = {}

function mmgen_simple.generate(current_layer, vm, area, vm_data, minp, maxp, offset_minp, offset_maxp, params)

	local nodetype = "default:stone"
	local height = 0

	if params and type(params) == "table" then
		if params.nodetype then nodetype = params.nodetype end
		if params.height then height = params.height end
	end

	local c_ground = multi_map.node[nodetype]

	if offset_minp.y >= height then
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.node["air"])
	else
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, c_ground)
	end

end
