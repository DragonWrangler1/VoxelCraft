--
-- Lava vs water interactions
--

minetest.register_abm({
	label = "Lava cooling",
	nodenames = {"group:lava"},
	neighbors = {"group:water"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local water = minetest.find_nodes_in_area({x=pos.x-1, y=pos.y-1, z=pos.z-1}, {x=pos.x+1, y=pos.y+1, z=pos.z+1}, "group:water")

		local lavatype = minetest.registered_nodes[node.name].liquidtype

		for w=1, #water do
			local waternode = minetest.get_node(water[w])
			local watertype = minetest.registered_nodes[waternode.name].liquidtype
			-- Lava on top of water: Water turns into stone
			if water[w].y < pos.y and water[w].x == pos.x and water[w].z == pos.z then
				minetest.set_node(water[w], {name="mcl_core:stone"})
				minetest.sound_play("fire_extinguish_flame", {pos = water[w], gain = 0.25, max_hear_distance = 16})
			-- Flowing lava vs water on same level: Lava turns into cobblestone
			elseif lavatype == "flowing" and water[w].y == pos.y and (water[w].x == pos.x or water[w].z == pos.z) then
				minetest.set_node(pos, {name="mcl_core:cobble"})
				minetest.sound_play("fire_extinguish_flame", {pos = pos, gain = 0.25, max_hear_distance = 16})
			-- Still lava vs flowing water above or horizontally neighbored: Lava turns into obsidian
			elseif lavatype == "source" and
					((water[w].y > pos.y and water[w].x == pos.x and water[w].z == pos.z) or
					(water[w].y == pos.y and (water[w].x == pos.x or water[w].z == pos.z))) then
				minetest.set_node(pos, {name="mcl_core:obsidian"})
				minetest.sound_play("fire_extinguish_flame", {pos = pos, gain = 0.25, max_hear_distance = 16})
			-- Flowing water above flowing lava: Lava turns into cobblestone
			elseif watertype == "flowing" and lavatype == "flowing" and water[w].y > pos.y and water[w].x == pos.x and water[w].z == pos.z then
				minetest.set_node(pos, {name="mcl_core:cobble"})
				minetest.sound_play("fire_extinguish_flame", {pos = pos, gain = 0.25, max_hear_distance = 16})
			end
		end
	end,
})

--
-- Papyrus and cactus growing
--

-- Functions
mcl_core.grow_cactus = function(pos, node)
	pos.y = pos.y-1
	local name = minetest.get_node(pos).name
	if minetest.get_item_group(name, "sand") ~= 0 then
		pos.y = pos.y+1
		local height = 0
		while minetest.get_node(pos).name == "mcl_core:cactus" and height < 4 do
			height = height+1
			pos.y = pos.y+1
		end
		if height < 3 then
			if minetest.get_node(pos).name == "air" then
				minetest.set_node(pos, {name="mcl_core:cactus"})
			end
		end
	end
end

mcl_core.grow_reeds = function(pos, node)
	pos.y = pos.y-1
	local name = minetest.get_node(pos).name
	if minetest.get_item_group(name, "soil_sugarcane") ~= 0 then
		if minetest.find_node_near(pos, 1, {"group:water"}) == nil and minetest.find_node_near(pos, 1, {"group:frosted_ice"}) == nil then
			return
		end
		pos.y = pos.y+1
		local height = 0
		while minetest.get_node(pos).name == "mcl_core:reeds" and height < 3 do
			height = height+1
			pos.y = pos.y+1
		end
		if height < 3 then
			if minetest.get_node(pos).name == "air" then
				minetest.set_node(pos, {name="mcl_core:reeds"})
			end
		end
	end
end

-- ABMs


local function drop_attached_node(p)
	local nn = minetest.get_node(p).name
	minetest.remove_node(p)
	for _, item in pairs(minetest.get_node_drops(nn, "")) do
		local pos = {
			x = p.x + math.random()/2 - 0.25,
			y = p.y + math.random()/2 - 0.25,
			z = p.z + math.random()/2 - 0.25,
		}
		minetest.add_item(pos, item)
	end
end

-- Helper function for node actions for liquid flow
local liquid_flow_action = function(pos, group, action)
	local check_detach = function(pos, xp, yp, zp)
		local p = {x=pos.x+xp, y=pos.y+yp, z=pos.z+zp}
		local n = minetest.get_node_or_nil(p)
		if not n then
			return false
		end
		local d = minetest.registered_nodes[n.name]
		if not d then
			return false
		end
		--[[ Check if we want to perform the liquid action.
		* 1: Item must be in liquid group
		* 2a: If target node is below liquid, always succeed
		* 2b: If target node is horizontal to liquid: succeed if source, otherwise check param2 for horizontal flow direction ]]
		local range = d.liquid_range or 8
		if (minetest.get_item_group(n.name, group) ~= 0) and
				((yp > 0) or
				(yp == 0 and ((d.liquidtype == "source") or (n.param2 > (8-range) and n.param2 < 9)))) then
			action(pos)
		end
	end
	local posses = {
		{ x=-1, y=0, z=0 },
		{ x=1, y=0, z=0 },
		{ x=0, y=0, z=-1 },
		{ x=0, y=0, z=1 },
		{ x=0, y=1, z=0 },
	}
	for p=1,#posses do
		check_detach(pos, posses[p].x, posses[p].y, posses[p].z)
	end
end

-- Drop some nodes next to flowing water, if it would flow into the node
minetest.register_abm({
	label = "Wash away dig_by_water nodes by water flow",
	nodenames = {"group:dig_by_water"},
	neighbors = {"group:water"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		liquid_flow_action(pos, "water", function(pos)
			drop_attached_node(pos)
			minetest.dig_node(pos)
		end)
	end,
})

-- Destroy some nodes next to flowing lava, if it would flow into the node
minetest.register_abm({
	label = "Destroy destroy_by_lava_flow nodes by lava flow",
	nodenames = {"group:destroy_by_lava_flow"},
	neighbors = {"group:lava"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		liquid_flow_action(pos, "lava", function(pos)
			minetest.remove_node(pos)
			minetest.sound_play("builtin_item_lava", {pos = pos, gain = 0.25, max_hear_distance = 16})
			core.check_for_falling(pos)
		end)
	end,
})

minetest.register_abm({
	label = "Cactus growth",
	nodenames = {"mcl_core:cactus"},
	neighbors = {"group:sand"},
	interval = 25,
	chance = 10,
	action = function(pos)
		mcl_core.grow_cactus(pos)
	end,
})

minetest.register_abm({
	label = "Sugar canes growth",
	nodenames = {"mcl_core:reeds"},
	neighbors = {"group:soil_sugarcane"},
	interval = 25,
	chance = 10,
	action = function(pos)
		mcl_core.grow_reeds(pos)
	end,
})

--
-- Papyrus and cactus drop
--

local timber_nodenames={"mcl_core:reeds"}

minetest.register_on_dignode(function(pos, node)
	local i=1
	while timber_nodenames[i]~=nil do
		if node.name==timber_nodenames[i] then
			local np={x=pos.x, y=pos.y+1, z=pos.z}
			while minetest.get_node(np).name==timber_nodenames[i] do
				minetest.remove_node(np)
				if not minetest.settings:get_bool("creative_mode") then
					minetest.add_item(np, timber_nodenames[i])
				end
				np={x=np.x, y=np.y+1, z=np.z}
			end
		end
		i=i+1
	end
end)

local function air_leaf(leaftype)
	if math.random(0, 50) == 3 then
		return {name = "air"}
	else
		return {name = leaftype}
	end
end

function mcl_core.generate_tree(pos, trunk, leaves, typearbre)
	pos.y = pos.y-1
	local nodename = minetest.get_node(pos).name
		
	pos.y = pos.y+1
	if not minetest.get_node_light(pos) then
		return
	end
	local node
	if typearbre == nil or typearbre == 1 then
		node = {name = ""}
		for dy=1,4 do
			pos.y = pos.y+dy
			if minetest.get_node(pos).name ~= "air" then
				return
			end
			pos.y = pos.y-dy
		end
		node = {name = trunk}
		for dy=0,4 do
			pos.y = pos.y+dy
			if minetest.get_node(pos).name == "air" then
				minetest.add_node(pos, node)
			end
			pos.y = pos.y-dy
		end

		node = {name = leaves}
		pos.y = pos.y+3
		local rarity = 0
		if math.random(0, 10) == 3 then
			rarity = 1
		end
		for dx=-2,2 do
			for dz=-2,2 do
				for dy=0,3 do
					pos.x = pos.x+dx
					pos.y = pos.y+dy
					pos.z = pos.z+dz

					if dx == 0 and dz == 0 and dy==3 then
						if minetest.get_node(pos).name == "air" and math.random(1, 5) <= 4 then
							minetest.add_node(pos, node)
							minetest.add_node(pos, air_leaf(leaves))
						end
					elseif dx == 0 and dz == 0 and dy==4 then
						if minetest.get_node(pos).name == "air" and math.random(1, 5) <= 4 then
							minetest.add_node(pos, node)
							minetest.add_node(pos, air_leaf(leaves))
						end
					elseif math.abs(dx) ~= 2 and math.abs(dz) ~= 2 then
						if minetest.get_node(pos).name == "air" then
							minetest.add_node(pos, node)
							minetest.add_node(pos, air_leaf(leaves))
						end
					else
						if math.abs(dx) ~= 2 or math.abs(dz) ~= 2 then
							if minetest.get_node(pos).name == "air" and math.random(1, 5) <= 4 then
								minetest.add_node(pos, node)
								minetest.add_node(pos, air_leaf(leaves))
							end
						end
					end
					pos.x = pos.x-dx
					pos.y = pos.y-dy
					pos.z = pos.z-dz
				end
			end
		end
	elseif typearbre == 2 then
		node = {name = ""}
		
		-- can place big tree ?
		local tree_size = math.random(15, 25)
		for dy=1,4 do
			pos.y = pos.y+dy
			if minetest.get_node(pos).name ~= "air" then
				return
			end
			pos.y = pos.y-dy
		end
		
		--Cheak for placing big tree
		pos.y = pos.y-1
			for dz=0,1 do
					pos.z = pos.z + dz
					--> 0
					local name = minetest.get_node(pos).name
					if name == "mcl_core:dirt_with_grass"
					or name == "mcl_core:dirt_with_grass_snow"
					or  name == "mcl_core:dirt" then else
							return
					end
					pos.x = pos.x+1
					--> 1
					if name == "mcl_core:dirt_with_grass"
					or name == "mcl_core:dirt_with_grass_snow"
					or  name == "mcl_core:dirt" then else
							return
					end
					pos.x = pos.x-1
					pos.z = pos.z - dz
			end
		pos.y = pos.y+1
		
		
		-- Make tree with vine
		node = {name = trunk}
		for dy=0,tree_size do
			pos.y = pos.y+dy
			
			for dz=-1,2 do
				if dz == -1 then
					pos.z = pos.z + dz
					if math.random(1, 3) == 1 and minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = "mcl_core:vine", param2 = 4})
					end
					pos.x = pos.x+1
					if math.random(1, 3) == 1 and  minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = "mcl_core:vine", param2 = 4})
					end
					pos.x = pos.x-1
					pos.z = pos.z - dz
				elseif dz == 2 then
					pos.z = pos.z + dz
					if math.random(1, 3) == 1 and  minetest.get_node(pos).name == "air"then
						minetest.add_node(pos, {name = "mcl_core:vine", param2 = 5})
					end
					pos.x = pos.x+1
					if math.random(1, 3) == 1 and minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = "mcl_core:vine", param2 = 5})
					end
					pos.x = pos.x-1
					pos.z = pos.z - dz
				else
					pos.z = pos.z + dz
					pos.x = pos.x-1
					if math.random(1, 3) == 1  and minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = "mcl_core:vine", param2 = 2})
					end
					pos.x = pos.x+1
					if minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = trunk, param2=2})
					end
					pos.x = pos.x+1
					if minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = trunk, param2=2})
					end
					pos.x = pos.x+1
					if math.random(1, 3) == 1 and minetest.get_node(pos).name == "air" then
						minetest.add_node(pos, {name = "mcl_core:vine", param2 = 3})
					end
					pos.x = pos.x-2
					pos.z = pos.z - dz
				end
			end
			
			pos.y = pos.y-dy
		end

		-- make leaves
		node = {name = leaves}
		pos.y = pos.y+tree_size-4
		for dx=-4,4 do
			for dz=-4,4 do
				for dy=0,3 do
					pos.x = pos.x+dx
					pos.y = pos.y+dy
					pos.z = pos.z+dz

					if dx == 0 and dz == 0 and dy==3 then
						if minetest.get_node(pos).name == "air" or minetest.get_node(pos).name == "mcl_core:vine" and math.random(1, 2) == 1 then
							minetest.add_node(pos, node)
							end
					elseif dx == 0 and dz == 0 and dy==4 then
						if minetest.get_node(pos).name == "air" or minetest.get_node(pos).name == "mcl_core:vine"  and math.random(1, 5) == 1 then
							minetest.add_node(pos, node)
								minetest.add_node(pos, air_leaf(leaves))
						end
					elseif math.abs(dx) ~= 2 and math.abs(dz) ~= 2 then
						if minetest.get_node(pos).name == "air" or minetest.get_node(pos).name == "mcl_core:vine"  then
							minetest.add_node(pos, node)
						end
					else
						if math.abs(dx) ~= 2 or math.abs(dz) ~= 2 then
							if minetest.get_node(pos).name == "air" or minetest.get_node(pos).name == "mcl_core:vine" and math.random(1, 3) == 1 then
								minetest.add_node(pos, node)
							end
						else
							if math.random(1, 5) == 1 and minetest.get_node(pos).name == "air" then
								minetest.add_node(pos, node)
							end
						end
					end
					pos.x = pos.x-dx
					pos.y = pos.y-dy
					pos.z = pos.z-dz
				end
			end
		end
	elseif typearbre == 3 then
		mcl_core.generate_spruce_tree(pos)
	elseif typearbre == 4 then
		mcl_core.grow_new_acacia_tree(pos)
	elseif typearbre == 5 then
		mcl_core.generate_jungle_tree(pos)
	end
end

-- BEGIN of spruce tree generation functions --
-- Copied from Minetest Game 0.4.15 from the pine tree (default.generate_pine_tree)

-- Pine tree (=spruce tree in MCL2) from mg mapgen mod, design by sfan5, pointy top added by paramat
local function add_spruce_leaves(data, vi, c_air, c_ignore, c_snow, c_spruce_leaves)
	local node_id = data[vi]
	if node_id == c_air or node_id == c_ignore or node_id == c_snow then
		data[vi] = c_spruce_leaves
	end
end

function mcl_core.generate_spruce_tree(pos)
	local x, y, z = pos.x, pos.y, pos.z
	local maxy = y + math.random(9, 13) -- Trunk top

	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")
	local c_spruce_tree = minetest.get_content_id("mcl_core:sprucetree")
	local c_spruce_leaves  = minetest.get_content_id("mcl_core:spruceleaves")
	local c_snow = minetest.get_content_id("mcl_core:snow")

	local vm = minetest.get_voxel_manip()
	local minp, maxp = vm:read_from_map(
		{x = x - 3, y = y, z = z - 3},
		{x = x + 3, y = maxy + 3, z = z + 3}
	)
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm:get_data()

	-- Upper branches layer
	local dev = 3
	for yy = maxy - 1, maxy + 1 do
		for zz = z - dev, z + dev do
			local vi = a:index(x - dev, yy, zz)
			local via = a:index(x - dev, yy + 1, zz)
			for xx = x - dev, x + dev do
				if math.random() < 0.95 - dev * 0.05 then
					add_spruce_leaves(data, vi, c_air, c_ignore, c_snow,
						c_spruce_leaves)
				end
				vi  = vi + 1
				via = via + 1
			end
		end
		dev = dev - 1
	end

	-- Centre top nodes
	add_spruce_leaves(data, a:index(x, maxy + 1, z), c_air, c_ignore, c_snow,
		c_spruce_leaves)
	add_spruce_leaves(data, a:index(x, maxy + 2, z), c_air, c_ignore, c_snow,
		c_spruce_leaves) -- Paramat added a pointy top node

	-- Lower branches layer
	local my = 0
	for i = 1, 20 do -- Random 2x2 squares of leaves
		local xi = x + math.random(-3, 2)
		local yy = maxy + math.random(-6, -5)
		local zi = z + math.random(-3, 2)
		if yy > my then
			my = yy
		end
		for zz = zi, zi+1 do
			local vi = a:index(xi, yy, zz)
			local via = a:index(xi, yy + 1, zz)
			for xx = xi, xi + 1 do
				add_spruce_leaves(data, vi, c_air, c_ignore, c_snow,
					c_spruce_leaves)
				vi  = vi + 1
				via = via + 1
			end
		end
	end

	dev = 2
	for yy = my + 1, my + 2 do
		for zz = z - dev, z + dev do
			local vi = a:index(x - dev, yy, zz)
			local via = a:index(x - dev, yy + 1, zz)
			for xx = x - dev, x + dev do
				if math.random() < 0.95 - dev * 0.05 then
					add_spruce_leaves(data, vi, c_air, c_ignore, c_snow,
						c_spruce_leaves)
				end
				vi  = vi + 1
				via = via + 1
			end
		end
		dev = dev - 1
	end

	-- Trunk
	-- Force-place lowest trunk node to replace sapling
	data[a:index(x, y, z)] = c_spruce_tree
	for yy = y + 1, maxy do
		local vi = a:index(x, yy, z)
		local node_id = data[vi]
		if node_id == c_air or node_id == c_ignore or
				node_id == c_spruce_leaves or node_id == c_snow then
			data[vi] = c_spruce_tree
		end
	end

	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
end

-- END of spruce tree functions --

-- Acacia tree grow function from Minetest Game 0.4.15
function mcl_core.grow_new_acacia_tree(pos)
	local path = minetest.get_modpath("mcl_core") ..
		"/schematics/acacia_tree_from_sapling.mts"
	minetest.place_schematic({x = pos.x - 4, y = pos.y - 1, z = pos.z - 4}, path, "random", nil, false)
end

-- Helper function for jungle tree, form Minetest Game 0.4.15
local function add_trunk_and_leaves(data, a, pos, tree_cid, leaves_cid,
		height, size, iters)
	local x, y, z = pos.x, pos.y, pos.z
	local c_air = minetest.CONTENT_AIR
	local c_ignore = minetest.CONTENT_IGNORE

	-- Trunk
	data[a:index(x, y, z)] = tree_cid -- Force-place lowest trunk node to replace sapling
	for yy = y + 1, y + height - 1 do
		local vi = a:index(x, yy, z)
		local node_id = data[vi]
		if node_id == c_air or node_id == c_ignore or node_id == leaves_cid then
			data[vi] = tree_cid
		end
	end

	-- Force leaves near the trunk
	for z_dist = -1, 1 do
	for y_dist = -size, 1 do
		local vi = a:index(x - 1, y + height + y_dist, z + z_dist)
		for x_dist = -1, 1 do
			if data[vi] == c_air or data[vi] == c_ignore then
				data[vi] = leaves_cid
			end
			vi = vi + 1
		end
	end
	end

	-- Randomly add leaves in 2x2x2 clusters.
	for i = 1, iters do
		local clust_x = x + math.random(-size, size - 1)
		local clust_y = y + height + math.random(-size, 0)
		local clust_z = z + math.random(-size, size - 1)

		for xi = 0, 1 do
		for yi = 0, 1 do
		for zi = 0, 1 do
			local vi = a:index(clust_x + xi, clust_y + yi, clust_z + zi)
			if data[vi] == c_air or data[vi] == c_ignore then
				data[vi] = leaves_cid
			end
		end
		end
		end
	end
end

-- Old jungle tree grow function from Minetest Game 0.4.15, imitating v6 jungle trees
function mcl_core.generate_jungle_tree(pos)
	--[[
		NOTE: Jungletree-placing code is currently duplicated in the engine
		and in games that have saplings; both are deprecated but not
		replaced yet
	--]]

	local x, y, z = pos.x, pos.y, pos.z
	local height = math.random(8, 12)
	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")
	local c_jungletree = minetest.get_content_id("mcl_core:jungletree")
	local c_jungleleaves = minetest.get_content_id("mcl_core:jungleleaves")

	local vm = minetest.get_voxel_manip()
	local minp, maxp = vm:read_from_map(
		{x = x - 3, y = y - 1, z = z - 3},
		{x = x + 3, y = y + height + 1, z = z + 3}
	)
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm:get_data()

	add_trunk_and_leaves(data, a, pos, c_jungletree, c_jungleleaves, height, 3, 30)

	-- Roots
	for z_dist = -1, 1 do
		local vi_1 = a:index(x - 1, y - 1, z + z_dist)
		local vi_2 = a:index(x - 1, y, z + z_dist)
		for x_dist = -1, 1 do
			if math.random(1, 3) >= 2 then
				if data[vi_1] == c_air or data[vi_1] == c_ignore then
					data[vi_1] = c_jungletree
				elseif data[vi_2] == c_air or data[vi_2] == c_ignore then
					data[vi_2] = c_jungletree
				end
			end
			vi_1 = vi_1 + 1
			vi_2 = vi_2 + 1
		end
	end

	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
end



local grass_spread_randomizer = PseudoRandom(minetest.get_mapgen_setting("seed"))

------------------------------
-- Spread grass blocks and mycelium on neighbor dirt
------------------------------
minetest.register_abm({
	label = "Grass Block and Mycelium spread",
	nodenames = {"mcl_core:dirt"},
	neighbors = {"air", "mcl_core:dirt_with_grass", "mcl_core:mycelium"},
	interval = 30,
	chance = 20,
	catch_up = false,
	action = function(pos)
		if pos == nil then
			return
		end
		local can_change = false
		local above = {x=pos.x, y=pos.y+1, z=pos.z}
		local abovenode = minetest.get_node(above)
		if minetest.get_item_group(abovenode.name, "liquid") ~= 0 or minetest.get_item_group(abovenode.name, "opaque") == 1 then
			-- Never grow directly below liquids or opaque blocks
			return
		end
		local light_self = minetest.get_node_light(above)
		if not light_self then return end
		--[[ Try to find a spreading dirt-type block (e.g. grass block or mycelium)
		within a 3×5×3 area, with the source block being on the 2nd-topmost layer. ]]
		local nodes = minetest.find_nodes_in_area({x=pos.x-1, y=pos.y-1, z=pos.z-1}, {x=pos.x+1, y=pos.y+3, z=pos.z+1}, "group:spreading_dirt_type")
		local p2
		-- Nothing found ? Bail out!
		if #nodes <= 0 then
			return
		else
			p2 = nodes[grass_spread_randomizer:next(1, #nodes)]
		end

		-- Found it! Now check light levels!
		local source_above = {x=p2.x, y=p2.y+1, z=p2.z}
		local light_source = minetest.get_node_light(source_above)
		if not light_source then return end

		if light_self >= 4 and light_source >= 9 then
			-- All checks passed! Let's spread the grass/mycelium!
			local n2 = minetest.get_node(p2)
			minetest.set_node(pos, {name=n2.name})

			-- If this was mycelium, uproot plant above
			if n2.name == "mcl_core:mycelium" then
				local tad = minetest.registered_nodes[minetest.get_node(above).name]
				if tad.groups and tad.groups.non_mycelium_plant then
					minetest.dig_node(above)
				end
			end
		end
	end
})

-- Grass/mycelium death in darkness
minetest.register_abm({
	label = "Grass Block / Mycelium in darkness",
	nodenames = {"group:spreading_dirt_type"},
	interval = 8,
	chance = 50,
	catch_up = false,
	action = function(pos, node)
		local above = {x = pos.x, y = pos.y + 1, z = pos.z}
		local name = minetest.get_node(above).name
		-- Kill grass/mycelium when below opaque block or liquid
		if name ~= "ignore" and (minetest.get_item_group(name, "opaque") == 1 or minetest.get_item_group(name, "liquid") ~= 0) then
			minetest.set_node(pos, {name = "mcl_core:dirt"})
		end
	end
})

-- Turn Grass Path and similar nodes to Dirt if a solid node is placed above it
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if minetest.get_item_group(newnode.name, "solid") ~= 0 then
		local below = {x=pos.x, y=pos.y-1, z=pos.z}
		local belownode = minetest.get_node(below)
		if minetest.get_item_group(belownode.name, "dirtifies_below_solid") == 1 then
			minetest.set_node(below, {name="mcl_core:dirt"})
		end
	end
end)

minetest.register_abm({
	label = "Turn Grass Path below solid block into Dirt",
	nodenames = {"mcl_core:grass_path"},
	neighbors = {"group:solid"},
	interval = 8,
	chance = 50,
	action = function(pos, node)
		local above = {x = pos.x, y = pos.y + 1, z = pos.z}
		local name = minetest.get_node(above).name
		local nodedef = minetest.registered_nodes[name]
		if name ~= "ignore" and nodedef and (nodedef.groups and nodedef.groups.solid) then
			minetest.set_node(pos, {name = "mcl_core:dirt"})
		end
	end,
})

--------------------------
-- Try generate tree   ---
--------------------------
local treelight = 9

local sapling_grow_action = function(trunknode, leafnode, tree_id, soil_needed)
	return function(pos)
		local light = minetest.get_node_light(pos)
		local soilnode = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})
		local soiltype = minetest.get_item_group(soilnode.name, "soil_sapling")
		if soiltype >= soil_needed and light and light >= treelight then
			-- Increase and check growth stage
			local meta = minetest.get_meta(pos)
			local stage = meta:get_int("stage")
			if stage == nil then stage = 0 end
			stage = stage + 1
			if stage >= 3 then
				minetest.set_node(pos, {name="air"})
				mcl_core.generate_tree(pos, trunknode, leafnode, tree_id)
			else
				meta:set_int("stage", stage)
			end
		end
	end
end

-- Attempts to grow the sapling at the specified position
-- pos: Position
-- node: Node table of the node at this position, from minetest.get_node
-- Returns true on success and false on failure
mcl_core.grow_sapling = function(pos, node)
	local grow
	if node.name == "mcl_core:sapling" then
		grow = sapling_grow_action("mcl_core:tree", "mcl_core:leaves", 1, 1)
	elseif node.name == "mcl_core:darksapling" then
		grow = sapling_grow_action("mcl_core:darktree", "mcl_core:darkleaves", 1, 2)
	elseif node.name == "mcl_core:junglesapling" then
		grow = sapling_grow_action("mcl_core:jungletree", "mcl_core:jungleleaves", 5, 1)
	elseif node.name == "mcl_core:acaciasapling" then
		grow = sapling_grow_action("mcl_core:acaciatree", "mcl_core:acacialeaves", 4, 2)
	elseif node.name == "mcl_core:sprucesapling" then
		grow = sapling_grow_action("mcl_core:sprucetree", "mcl_core:spruceleaves", 3, 1)
	elseif node.name == "mcl_core:birchsapling" then
		grow = sapling_grow_action("mcl_core:birchtree", "mcl_core:birchleaves", 1, 1)
	end
	if grow then
		grow(pos)
		return true
	else
		return false
	end
end

-- TODO: Use better tree models for everything
-- TODO: Support 2×2 saplings

-- Oak tree
minetest.register_abm({
	label = "Oak tree growth",
	nodenames = {"mcl_core:sapling"},
	neighbors = {"group:soil_sapling"},
	interval = 25,
	chance = 2,
	action = sapling_grow_action("mcl_core:tree", "mcl_core:leaves", 1, 1),
})

-- Dark oak tree
minetest.register_abm({
	label = "Dark oak tree growth",
	nodenames = {"mcl_core:darksapling"},
	neighbors = {"group:soil_sapling"},
	interval = 25,
	chance = 2,
	action = sapling_grow_action("mcl_core:darktree", "mcl_core:darkleaves", 1, 2),
})

-- Jungle Tree
minetest.register_abm({
	label = "Jungle tree growth",
	nodenames = {"mcl_core:junglesapling"},
	neighbors = {"group:soil_sapling"},
	interval = 25,
	chance = 2,
	action = sapling_grow_action("mcl_core:jungletree", "mcl_core:jungleleaves", 5, 1)
})

-- Spruce tree
minetest.register_abm({
	label = "Spruce tree growth",
	nodenames = {"mcl_core:sprucesapling"},
	neighbors = {"group:soil_sapling"},
	interval = 25,
	chance = 2,
	action = sapling_grow_action("mcl_core:sprucetree", "mcl_core:spruceleaves", 3, 1),
})

-- Birch tree
minetest.register_abm({
	label = "Birch tree growth",
	nodenames = {"mcl_core:birchsapling"},
	neighbors = {"group:soil_sapling"},
	interval = 25,
	chance = 2,
	action = sapling_grow_action("mcl_core:birchtree", "mcl_core:birchleaves", 1, 1),
})

-- Acacia tree
minetest.register_abm({
	label = "Acacia tree growth",
	nodenames = {"mcl_core:acaciasapling"},
	neighbors = {"group:soil_sapling"},
	interval = 20,
	chance = 2,
	action = sapling_grow_action("mcl_core:acaciatree", "mcl_core:acacialeaves", 4, 2),
})

---------------------
-- Vine generating --
---------------------
minetest.register_abm({
	label = "Vines growth",
	nodenames = {"mcl_core:vine"},
	interval = 47,
	chance = 4,
	action = function(pos, node, active_object_count, active_object_count_wider)

		local neighbor_offsets = {
			{ x=1, y=0, z=0 },
			{ x=-1, y=0, z=0 },
			{ x=0, y=0, z=1 },
			{ x=0, y=0, z=-1 },
		}

		-- Add vines below pos (if empty)
		local spread_down = function(pos, node)
			local down = vector.add(pos, {x=0, y=-1, z=0})
			if minetest.get_node(down).name == "air" then
				minetest.add_node(down, {name = "mcl_core:vine", param2 = node.param2})
			end
		end

		-- Add vines above pos if it is backed up
		local spread_up = function(pos, node)
			local up = vector.add(pos, {x=0, y=1, z=0})
			if minetest.get_node(up).name == "air" then
				local backup_dir = minetest.facedir_to_dir(node.param2)
				local backup = vector.add(up, backup_dir)
				local backupnodename = minetest.get_node(backup).name

				-- Check if the block above is supported
				if mcl_core.supports_vines(backupnodename) then
					minetest.add_node(up, {name = "mcl_core:vine", param2 = node.param2})
				end
			end
		end

		-- Try to spread vines from the 4 horizontal neighbors
		local spread_neighbors = function(pos, node, spread_dir)
			for n=1, #neighbor_offsets do
				if math.random(1,2) == 1 then
					local neighbor = vector.add(pos, neighbor_offsets[n])
					local neighbornode = minetest.get_node(neighbor)
					if neighbornode.name == "mcl_core:vine" then
						if spread_dir == "up" then
							spread_up(neighbor, neighbornode)
						elseif spread_dir == "down" then
							spread_down(neighbor, neighbornode)
						end
					end
				end
			end
		end

		-- Spread down
		local down = {x=pos.x, y=pos.y-1, z=pos.z}
		local down_node = minetest.get_node(down)
		if down_node.name == "air" then
			spread_neighbors(pos, node, "down")
		elseif down_node.name == "mcl_core:vine" then
			spread_neighbors(down, down_node, "down")
		end

		-- Spread up
		local up = {x=pos.x, y=pos.y+1, z=pos.z}
		local up_node = minetest.get_node(up)
		if up_node.name == "air" then
			local vines_in_area = minetest.find_nodes_in_area({x=pos.x-4, y=pos.y-1, z=pos.z-4}, {x=pos.x+4, y=pos.y+1, z=pos.z+4}, "mcl_core:vine")
			-- Less then 4 vines blocks around the ticked vines block (remember the ticked block is counted by above function as well)
			if #vines_in_area < 5 then
				spread_neighbors(pos, node, "up")
			end
		end

		-- TODO: Spread horizontally

	end
})

-- Returns true of the node supports vines
mcl_core.supports_vines = function(nodename)
	local def = minetest.registered_nodes[nodename]
	-- Rules: 1) walkable 2) full cube
	return def.walkable and ((not def.node_box) or def.node_box.type == "regular")
end

-- Leaf Decay

-- To enable leaf decay for a node, add it to the "leafdecay" group.
--
-- The rating of the group determines how far from a node in the group "tree"
-- the node can be without decaying.
--
-- If param2 of the node is ~= 0, the node will always be preserved. Thus, if
-- the player places a node of that kind, you will want to set param2=1 or so.
--
-- If the node is in the leafdecay_drop group then the it will always be dropped
-- as an item

mcl_core.leafdecay_trunk_cache = {}
mcl_core.leafdecay_enable_cache = true
-- Spread the load of finding trunks
mcl_core.leafdecay_trunk_find_allow_accumulator = 0

minetest.register_globalstep(function(dtime)
	local finds_per_second = 5000
	mcl_core.leafdecay_trunk_find_allow_accumulator =
			math.floor(dtime * finds_per_second)
end)

minetest.register_abm({
	label = "Leaf decay",
	nodenames = {"group:leafdecay"},
	neighbors = {"air", "group:liquid"},
	-- A low interval and a high inverse chance spreads the load
	interval = 2,
	chance = 5,

	action = function(p0, node, _, _)
		local do_preserve = false
		local d = minetest.registered_nodes[node.name].groups.leafdecay
		if not d or d == 0 then
			return
		end
		local n0 = minetest.get_node(p0)
		if n0.param2 ~= 0 then
			-- Prevent leafdecay for player-placed leaves.
			-- param2 is set to 1 after it was placed by the player
			return
		end
		local p0_hash = nil
		if mcl_core.leafdecay_enable_cache then
			p0_hash = minetest.hash_node_position(p0)
			local trunkp = mcl_core.leafdecay_trunk_cache[p0_hash]
			if trunkp then
				local n = minetest.get_node(trunkp)
				local reg = minetest.registered_nodes[n.name]
				-- Assume ignore is a trunk, to make the thing work at the border of the active area
				if n.name == "ignore" or (reg and reg.groups.tree and reg.groups.tree ~= 0) then
					return
				end
				-- Cache is invalid
				table.remove(mcl_core.leafdecay_trunk_cache, p0_hash)
			end
		end
		if mcl_core.leafdecay_trunk_find_allow_accumulator <= 0 then
			return
		end
		mcl_core.leafdecay_trunk_find_allow_accumulator =
				mcl_core.leafdecay_trunk_find_allow_accumulator - 1
		-- Assume ignore is a trunk, to make the thing work at the border of the active area
		local p1 = minetest.find_node_near(p0, d, {"ignore", "group:tree"})
		if p1 then
			do_preserve = true
			if mcl_core.leafdecay_enable_cache then
				-- Cache the trunk
				mcl_core.leafdecay_trunk_cache[p0_hash] = p1
			end
		end
		if not do_preserve then
			-- Drop stuff other than the node itself
			local itemstacks = minetest.get_node_drops(n0.name)
			for _, itemname in ipairs(itemstacks) do
				if minetest.get_item_group(n0.name, "leafdecay_drop") ~= 0 or
						itemname ~= n0.name then
					local p_drop = {
						x = p0.x - 0.5 + math.random(),
						y = p0.y - 0.5 + math.random(),
						z = p0.z - 0.5 + math.random(),
					}
					minetest.add_item(p_drop, itemname)
				end
			end
			-- Remove node
			minetest.remove_node(p0)
			core.check_for_falling(p0)
		end
	end
})

