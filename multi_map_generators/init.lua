local multi_map_generators_path = minetest.get_modpath("multi_map_generators")

multi_map.number_of_layers = 38
multi_map.layers_start_chunk = 0
multi_map.layer_height_chunks = 20
--multi_map.wrap_layers = true

dofile(multi_map_generators_path.."/mmgen_levels.lua")
--dofile(multi_map_generators_path.."/mmgen_lvm_example.lua")
dofile(multi_map_generators_path.."/mmgen_simple.lua")
dofile(multi_map_generators_path.."/mmgen_testauri.lua")

--multi_map.register_fallback_generator("Default Simple", mmgen_simple.generate)
--multi_map.register_generator(9, mmgen_simple.generate, "default:sandstone")
--multi_map.set_layer_name(9, "Desert")
--multi_map.register_generator(10, mmgen_levels.generate)
--multi_map.register_generator(11, mmgen_testauri.generate)
--multi_map.register_generator(12, mmgen_testauri.generate)
--multi_map.register_generator(13, mmgen_levels.generate)

multi_map.register_fallback_generator(mmgen_simple.generate)

--multi_map.register_generator(18, mmgen_testauri.generate)
--multi_map.register_generator(19, mmgen_testauri.generate)
--multi_map.register_generator(20, mmgen_testauri.generate)

--multi_map.register_linked_layer(19, multi_map.world_edge.POSITIVE_X, 19, true)
--multi_map.register_linked_layer(19, multi_map.world_edge.POSITIVE_Z, 19, true)

multi_map.register_fallback_generator("Default Levels", mmgen_levels.generate)
multi_map.register_generator(18, mmgen_levels.generate)
multi_map.register_generator(19, mmgen_testauri.generate)
multi_map.register_generator(20, mmgen_levels.generate)
multi_map.set_layer_params(18, { name = "Lowlands Layer" })
multi_map.set_layer_params(19, { name = "Central Layer" })
multi_map.set_layer_params(20, { name = "Remote Levels Land" })
