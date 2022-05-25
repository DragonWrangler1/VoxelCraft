local S = minetest.get_translator(minetest.get_current_modname())
-- Loom Code. Used to craft banner designs easier. Still needs a GUI. https://minecraft.fandom.com/wiki/Loom
	
minetest.register_node("mcl_loom:loom", {
	description = S("Loom"),
	_tt_help = S("Used to create banner designs"),
	_doc_items_longdesc = S("This is the shepherd villager's work station. It is used to create banner designs."),
	tiles = {
		"loom_top.png", "loom_bottom.png",
		"loom_side.png", "loom_side.png",
		"loom_front.png", "loom_front.png"
	},
	paramtype2 = "facedir",
	groups = {choppy=1, deco_block=1, material_wood=1, flammable=1}
	})
	

minetest.register_craft({
	output = "mcl_loom:loom",
	recipe = {
		{ "", "", "" },
		{ "mcl_mobitems:string", "mcl_mobitems:string", "" },
		{ "group:wood", "group:wood", "" },
	}
})