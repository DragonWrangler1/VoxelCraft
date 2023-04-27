mcl_copper = {}
local path = minetest.get_modpath("mcl_copper")

dofile(path .. "/decaychains.lua")
dofile(path .. "/nodes.lua")
dofile(path .. "/items.lua")
dofile(path .. "/crafting.lua")

mcl_copper.register_decaychain("copper",{
	preserved_description = "Waxed ",
	preserve_group = "preserves_copper",
	unpreserve_group = "axe",
    --decay_group = "oxidizes_copper",
	undecay_group = "axe",
	nodes = { --order is significant
		"mcl_copper:block",
		"mcl_copper:block_exposed",
		"mcl_copper:block_weathered",
		"mcl_copper:block_oxidized",
	},
})

mcl_copper.register_decaychain("cut_copper",{
	preserved_description = "Waxed ",
	preserve_group = "preserves_copper",
	unpreserve_group = "axe",
    --decay_group = "oxidizes_copper",
	undecay_group = "axe",
	nodes = { --order is significant
		"mcl_copper:block_cut",
		"mcl_copper:block_exposed_cut",
		"mcl_copper:block_weathered_cut",
		"mcl_copper:block_oxidized_cut",
	},
})

--TODO: stairs and slabs
