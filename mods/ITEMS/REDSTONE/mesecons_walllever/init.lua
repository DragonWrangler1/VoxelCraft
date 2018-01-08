local lever_get_output_rules = function(node)
	local rules = {
		{x = -1, y = 0, z = 0},
		{x = 1, y = 0, z = 0},
		{x = 0, y = 0, z = -1},
		{x = 0, y = 0, z = 1},
		{x = 0, y = -1, z = 0},
		{x = 0, y = 1, z = 0},
	}
	local dir = minetest.facedir_to_dir(node.param2)
	dir = vector.multiply(dir, 2)
	table.insert(rules, dir)
	return rules
end

-- LEVER
minetest.register_node("mesecons_walllever:wall_lever_off", {
	drawtype = "mesh",
	tiles = {
		"jeija_wall_lever_lever_light_on.png",
	},
	inventory_image = "jeija_wall_lever.png",
	wield_image = "jeija_wall_lever.png",
	paramtype = "light",
	paramtype2 = "facedir",
	drawtype = "mesh",
	mesh = "jeija_wall_lever_off.obj",
	sunlight_propagates = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = { -3/16, -8/16,  -4/16, 3/16, -2/16,  4/16 },
	},
	groups = {handy=1, dig_by_water=1, destroy_by_lava_flow=1, dig_by_piston=1},
	is_ground_content = false,
	description="Lever",
	_doc_items_longdesc = "A lever is a redstone component which can be flipped on and off. It supplies redstone power to the blocks behind while it is in the “on” state.",
	_doc_items_usagehelp = "Right-click the lever to flip it on or off.",
	on_rightclick = function (pos, node)
		minetest.swap_node(pos, {name="mesecons_walllever:wall_lever_on",param2=node.param2})
		mesecon:receptor_on(pos, lever_get_output_rules(node))
		minetest.sound_play("mesecons_lever", {pos=pos})
	end,
	node_placement_prediction = "",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			-- no interaction possible with entities
			return itemstack
		end

		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local def = minetest.registered_nodes[node.name]
		if not def then return end
		local groups = def.groups

		-- Check special rightclick action of pointed node
		if def and def.on_rightclick then
			if not placer:get_player_control().sneak then
				return def.on_rightclick(under, node, placer, itemstack,
					pointed_thing) or itemstack, false
			end
		end

		-- If the pointed node is buildable, let's look at the node *behind* that node
		if def.buildable_to then
			local dir = vector.subtract(pointed_thing.above, pointed_thing.under)
			local actual = vector.subtract(under, dir)
			local actualnode = minetest.get_node(actual)
			def = minetest.registered_nodes[actualnode.name]
			groups = def.groups
		end

		-- Only allow placement on full-cube solid opaque nodes
		if (not groups) or (not groups.solid) or (not groups.opaque) or (def.node_box and def.node_box.type ~= "regular") then
			return itemstack
		end

		local above = pointed_thing.above
		local dir = vector.subtract(above, under)
		local wdir
		local tau = math.pi*2
		if dir.z == 1 then
			wdir = 6
		elseif dir.z == -1 then
			wdir = 8
		elseif dir.x == 1 then
			wdir = 15
		elseif dir.x == -1 then
			wdir = 17
		elseif dir.y ~= 0 then
			local yaw = placer:get_look_horizontal()
			if (yaw > tau/8 and yaw < (tau/8)*3) or (yaw < (tau/8)*7 and yaw > (tau/8)*5) then
				if dir.y == -1 then
					wdir = 23
				else
					wdir = 1
				end
			else
				if dir.y == -1 then
					wdir = 22
				else
					wdir = 2
				end
			end
		end

		local idef = itemstack:get_definition()
		local itemstack, success = minetest.item_place_node(itemstack, placer, pointed_thing, wdir)

		if success then
			if idef.sounds and idef.sounds.place then
				minetest.sound_play(idef.sounds.place, {pos=above, gain=1})
			end
		end
		return itemstack
	end,

	sounds = mcl_sounds.node_sound_stone_defaults(),
	mesecons = {receptor = {
		rules = lever_get_output_rules,
		state = mesecon.state.off
	}},
	on_rotate = false,
	_mcl_blast_resistance = 2.5,
	_mcl_hardness = 0.5,
})
minetest.register_node("mesecons_walllever:wall_lever_on", {
	drawtype = "mesh",
	tiles = {
		"jeija_wall_lever_lever_light_on.png",
	},
	inventory_image = "jeija_wall_lever.png",
	paramtype = "light",
	paramtype2 = "facedir",
	mesh = "jeija_wall_lever_on.obj",
	sunlight_propagates = true,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = { -3/16, -8/16,  -4/16, 3/16, -2/16,  4/16 },
	},
	groups = {handy=1, not_in_creative_inventory = 1, dig_by_water=1, destroy_by_lava_flow=1, dig_by_piston=1},
	is_ground_content = false,
	drop = '"mesecons_walllever:wall_lever_off" 1',
	description="Lever",
	_doc_items_create_entry = false,
	on_rightclick = function (pos, node)
		minetest.swap_node(pos, {name="mesecons_walllever:wall_lever_off", param2=node.param2})
		mesecon:receptor_off(pos, lever_get_output_rules(node))
		minetest.sound_play("mesecons_lever", {pos=pos})
	end,
	sounds = mcl_sounds.node_sound_stone_defaults(),
	mesecons = {receptor = {
		rules = lever_get_output_rules,
		state = mesecon.state.on
	}},
	on_rotate = false,
	_mcl_blast_resistance = 2.5,
	_mcl_hardness = 0.5,
})

minetest.register_craft({
	output = 'mesecons_walllever:wall_lever_off',
	recipe = {
		{'mcl_core:stick'},
		{'mcl_core:cobble'},
	}
})

if minetest.get_modpath("doc") then
	doc.add_entry_alias("nodes", "mesecons_walllever:wall_lever_off", "nodes", "mesecons_walllever:wall_lever_on")
end
