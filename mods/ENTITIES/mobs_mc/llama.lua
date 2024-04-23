local S = minetest.get_translator("mobs_mc")

-- table mapping unified color names to non-conforming color names in carpet texture filenames
local messytextures = {
	grey = "gray",
	silver = "light_gray",
}

local function get_drops(self)
	local drops = {}
	table.insert(drops,
		{name = "mcl_mobitems:leather",
		chance = 1,
		min = 0,
		max = 2,
		looting = "common",
		})
	if self.carpet then
		table.insert(drops,{name = self.carpet,
		chance = 1,
		min = 1,
		max = 1,})
	end
	if self._has_chest then
		table.insert(drops,{name = "mcl_chests:chest",
		chance = 1,
		min = 1,
		max = 1,})
	end
	return drops
end

mcl_mobs.register_mob("mobs_mc:llama", {
	description = S("Llama"),
	type = "animal",
	spawn_class = "passive",
	passive = false,
	attack_type = "shoot",
	shoot_interval = 5.5,
	arrow = "mobs_mc:llamaspit",
	retaliates = true,
	specific_attack = { "player" },
	shoot_offset = 1, --3.5 *would* be a good value visually but it somehow messes with the projectiles trajectory
	spawn_in_group_min = 4,
	spawn_in_group = 6,

	head_swivel = "head.control",
	bone_eye_height = 11,
	head_eye_height = 3,
	horizontal_head_height=0,
	curiosity = 60,
	head_yaw = "z",

	hp_min = 15,
	hp_max = 30,
	xp_min = 1,
	xp_max = 3,
	collisionbox = {-0.45, -0.01, -0.45, 0.45, 1.86, 0.45},
	visual = "mesh",
	mesh = "mobs_mc_llama.b3d",
	textures = { -- 1: chest -- 2: decor (carpet) -- 3: llama base texture
		{"blank.png", "blank.png", "mobs_mc_llama_brown.png"},
		{"blank.png", "blank.png", "mobs_mc_llama_creamy.png"},
		{"blank.png", "blank.png", "mobs_mc_llama_gray.png"},
		{"blank.png", "blank.png", "mobs_mc_llama_white.png"},
		{"blank.png", "blank.png", "mobs_mc_llama.png"},
	},
	makes_footstep_sound = true,
	runaway = false,
	walk_velocity = 1,
	run_velocity = 4.4,
	follow_velocity = 4.4,
	floats = 1,
	drops = {
		{name = "mcl_mobitems:leather",
		chance = 1,
		min = 0,
		max = 2,
		looting = "common",},
	},
	fear_height = 4,
	sounds = {
		random = "mobs_mc_llama",
		eat = "mobs_mc_animal_eat_generic",
		-- TODO: Death and damage sounds
		distance = 16,
	},
	animation = {
		stand_start = 0, stand_end = 0,
		walk_start = 0, walk_end = 40, walk_speed = 35,
		run_start = 0, run_end = 40, run_speed = 50,
	},
	child_animations = {
		stand_start = 41, stand_end = 41,
		walk_start = 41, walk_end = 81, walk_speed = 50,
		run_start = 41, run_end = 81, run_speed = 75,
	},
	follow = { "mcl_farming:wheat_item", "mcl_farming:hay_block" },
	view_range = 16,
	do_custom = function(self, dtime)
		if not self.v3 then
			local vsize = self.object:get_properties().visual_size
			self.v3 = 0
			self.max_speed_forward = 4
			self.max_speed_reverse = 2
			self.accel = 4
			self.terrain_type = 3
			self.driver_attach_at = {x = 0, y = 12.7, z = -5}
			self.driver_eye_offset = {x = 0, y = 6, z = 0}
			self.driver_scale = {x = 1/vsize.x, y = 1/vsize.y}
		end

		if self.driver then
			mcl_mobs.drive(self, "walk", "stand", false, dtime)
			return false
		end

		return true
	end,

	on_die = function(self, pos)
		if self.driver then
			mcl_mobs.detach(self.driver, {x = 1, y = 0, z = 1})
		end

	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end

		local item = clicker:get_wielded_item()
		if item:get_name() == "mcl_farming:hay_block" then
			if self:feed_tame(clicker, 1, true, false) then return end
		elseif not self._has_chest and item:get_name() == "mcl_chests:chest" then
			item:take_item()
			clicker:set_wielded_item(item)
			self._has_chest = true
			self.base_texture = table.copy(self.base_texture)
			self.base_texture[1] = self.base_texture[3]
			self.object:set_properties({
				textures = self.base_texture,
			})
			self:update_drops()
			return
		elseif self._has_chest and clicker:get_player_control().sneak then
			mcl_entity_invs.show_inv_form(self,clicker," - Strength "..math.floor(self._inv_size / 3))
			return
		else
			if self:feed_tame(clicker, 1, false, true) then return end
		end
		if mcl_mobs.protect(self, clicker) then return end

		if self.tamed and not self.child and self.owner == clicker:get_player_name() then
			if minetest.get_item_group(item:get_name(), "carpet") == 1 and self:set_carpet(item, clicker) then
				return
			end

			if self.driver and clicker == self.driver then
				mcl_mobs.detach(clicker, {x = 1, y = 0, z = 1})
			elseif not self.driver then
				self.object:set_properties({stepheight = 1.1})
				mcl_mobs.attach(self, clicker)
			end
		end
	end,
	update_drops = function(self)
		self.drops = get_drops(self)
	end,
	set_carpet = function(self, item, clicker)
		if self.carpet ~= item:get_name() then
			local idef = item:get_definition()
			if idef._color then
				if not minetest.is_creative_enabled(clicker:get_player_name()) then
					item:take_item()
					clicker:set_wielded_item(item)
					if self.carpet then
						minetest.add_item(self.object:get_pos(), self.carpet)
					end
				end
				self.base_texture[2] = "mobs_mc_llama_decor_"..(messytextures[idef._color] or idef._color)..".png"
				self.object:set_properties({
					textures = self.base_texture,
				})
				self.carpet = item:get_name()
				self:update_drops()
				return true
			end
		end
	end,

	on_breed = function(parent1, parent2)
		local pos = parent1.object:get_pos()
		local child, parent
		if math.random(1,2) == 1 then
			parent = parent1
		else
			parent = parent2
		end
		child = mcl_mobs.spawn_child(pos, parent.name)
		if child then
			local ent_c = child:get_luaentity()
			ent_c.base_texture = table.copy(ent_c.base_texture)
			ent_c.base_texture[2] = "blank.png"
			child:set_properties({textures = ent_c.base_texture})
			ent_c.tamed = true
			ent_c.carpet = nil
			ent_c.owner = parent.owner
			return false
		end
	end,
	on_spawn = function(self)
		if not self._inv_size then
			local r = math.random(1000)
			if r < 80 then
				self._inv_size = 15
			elseif r < 160 then
				self._inv_size = 12
			elseif r < 488 then
				self._inv_size = 9
			elseif r < 816 then
				self._inv_size = 6
			else
				self._inv_size = 3
			end
		end
	end,
})

mcl_entity_invs.register_inv("mobs_mc:llama","Llama",nil,true)

mcl_mobs.register_arrow("mobs_mc:llamaspit", {
	visual = "sprite",
	visual_size = {x = 0.10, y = 0.10},
	textures = {"mobs_mc_llama_spit.png"},
	velocity = 5,
	hit_player = mcl_mobs.get_arrow_damage_func(1),
})


mcl_mobs.spawn_setup({
	name = "mobs_mc:llama",
	type_of_spawning = "ground",
	dimension = "overworld",
	aoc = 5,
	min_height = mobs_mc.water_level+15,
	biomes = {
		"Savanna",
		"SavannaM",
		"SavannaM_beach",
		"Savanna_beach",
		"Savanna_ocean",
		"ExtremeHills",
		"ExtremeHills_beach",
		"ExtremeHillsM",
	},
	chance = 50,
})

mcl_mobs.register_egg("mobs_mc:llama", S("Llama"), "#c09e7d", "#995f40", 0)
