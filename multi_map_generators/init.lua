local multi_map_generators_path = minetest.get_modpath("multi_map_generators")

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

multi_map.number_of_layers = 38
multi_map.layers_start_chunk = 0
multi_map.layer_height_chunks = 20
multi_map.wrap_layers = true

multi_map.register_fallback_generator(mmgen_simple.generate)

multi_map.register_generator(0, mmgen_testauri.generate)
multi_map.register_generator(1, mmgen_testauri.generate)

multi_map.set_layer_params(0,
	{ name = "Bottom World 1", generate_bedrock = false, generate_skyrock = false, generate_shadow_caster = true })

multi_map.set_layer_params(1,
	{ name = "Bottom World 2", generate_bedrock = false, generate_skyrock = true })

multi_map.register_generator(2, mmgen_levels.generate)

multi_map.register_generator(18, mmgen_testauri.generate)
multi_map.register_generator(19, mmgen_testauri.generate)
multi_map.register_generator(20, mmgen_testauri.generate)

multi_map.register_linked_layer(19, multi_map.world_edge.POSITIVE_Z, 20, true)
multi_map.register_linked_layer(19, multi_map.world_edge.NEGATIVE_Z, 18, true)

--multi_map.register_generator(9, mmgen_simple.generate, { nodetype = "default:sandstone", height = 0 })
--multi_map.register_generator(9, mmgen_simple.generate, { nodetype = "default:sandstone", height = 1 })
--multi_map.register_fallback_generator("Default Levels", mmgen_levels.generate)
--multi_map.register_generator(19, mmgen_levels.generate)
--multi_map.set_layer_name(19, "Central Layer")
--multi_map.set_layer_name(20, "Remote Levels Land")
