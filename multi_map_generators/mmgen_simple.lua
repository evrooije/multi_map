mmgen_simple = {}

function mmgen_simple.generate(current_layer, minp, maxp, offset_minp, offset_maxp)
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local vm_data = vm:get_data()
	if offset_minp.y >= 0 then
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.c_air)
		vm:set_lighting({day=15, night=0})
	else
		multi_map.generate_singlenode_chunk(minp, maxp, area, vm_data, multi_map.c_stone)
	end
	vm:set_data(vm_data)
	vm:calc_lighting(false)
	vm:write_to_map(false)
end
