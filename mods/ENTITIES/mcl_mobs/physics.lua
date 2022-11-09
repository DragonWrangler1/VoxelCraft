local math, vector, minetest, mcl_mobs = math, vector, minetest, mcl_mobs
local mob_class = mcl_mobs.mob_class

local ENTITY_CRAMMING_MAX = 24
local CRAMMING_DAMAGE = 3
local DEFAULT_FALL_SPEED = -9.81*1.5


-- get node but use fallback for nil or unknown
local node_ok = function(pos, fallback)

	fallback = fallback or mcl_mobs.fallback_node

	local node = minetest.get_node_or_nil(pos)

	if node and minetest.registered_nodes[node.name] then
		return node
	end

	return minetest.registered_nodes[fallback]
end

-- check if within physical map limits (-30911 to 30927)
local function within_limits(pos, radius)
	local wmin, wmax = -30912, 30928
	if mcl_vars then
		if mcl_vars.mapgen_edge_min and mcl_vars.mapgen_edge_max then
			wmin, wmax = mcl_vars.mapgen_edge_min, mcl_vars.mapgen_edge_max
		end
	end
	if radius then
		wmin = wmin - radius
		wmax = wmax + radius
	end
	for _,v in pairs(pos) do
		if v < wmin or v > wmax then return false end
	end
	return true
end

-- collision function borrowed amended from jordan4ibanez open_ai mod
function mob_class:collision()
	local pos = self.object:get_pos()
	if not pos then return {0,0} end
	local vel = self.object:get_velocity()
	local x = 0
	local z = 0
	local width = -self.collisionbox[1] + self.collisionbox[4] + 0.5
	for _,object in pairs(minetest.get_objects_inside_radius(pos, width)) do

		local ent = object:get_luaentity()
		if object:is_player() or (ent and ent.is_mob and object ~= self.object) then

			if object:is_player() and mcl_burning.is_burning(self.object) then
				mcl_burning.set_on_fire(object, 4)
			end

			local pos2 = object:get_pos()
			local vec  = {x = pos.x - pos2.x, z = pos.z - pos2.z}
			local force = (width + 0.5) - vector.distance(
				{x = pos.x, y = 0, z = pos.z},
				{x = pos2.x, y = 0, z = pos2.z})

			x = x + (vec.x * force)
			z = z + (vec.z * force)
		end
	end

	return({x,z})
end

-- move mob in facing direction
function mob_class:set_velocity( v)

	local c_x, c_y = 0, 0

	-- can mob be pushed, if so calculate direction
	if self.pushable then
		c_x, c_y = unpack(self:collision())
	end

	-- halt mob if it has been ordered to stay
	if self.order == "stand" or self.order == "sit" then
	  self.acc=vector.new(0,0,0)
	  return
	end

	local yaw = (self.object:get_yaw() or 0) + self.rotate
	local vv = self.object:get_velocity()
	if vv then
		self.acc={
		  x = ((math.sin(yaw) * -v) + c_x)*.27,
		  y = 0,
		  z = ((math.cos(yaw) * v) + c_y)*.27,
		}
	end
end

-- calculate mob velocity
function mob_class:get_velocity()

	local v = self.object:get_velocity()
	if v then
		return (v.x * v.x + v.z * v.z) ^ 0.5
	end

	return 0
end

function mob_class:update_roll()
	local is_Fleckenstein = self.nametag == "Fleckenstein"
	local was_Fleckenstein = false

	local rot = self.object:get_rotation()
	rot.z = is_Fleckenstein and pi or 0
	self.object:set_rotation(rot)

	local cbox = table.copy(self.collisionbox)
	local acbox = self.object:get_properties().collisionbox

	if math.abs(cbox[2] - acbox[2]) > 0.1 then
		was_Fleckenstein = true
	end

	if is_Fleckenstein ~= was_Fleckenstein then
		local pos = self.object:get_pos()
		pos.y = pos.y + (acbox[2] + acbox[5])
		self.object:set_pos(pos)
	end

	if is_Fleckenstein then
		cbox[2], cbox[5] = -cbox[5], -cbox[2]
		self.object:set_properties({collisionbox = cbox})
	-- This leads to child mobs having the wrong collisionbox
	-- and seeing as it seems to be nothing but an easter egg
	-- i've put it inside the if. Which just makes it be upside
	-- down lol.
	end

end

function mob_class:update_tag()
	local tag
	if mobs_debug then
		tag = "nametag = '"..tostring(self.nametag).."'\n"..
		"state = '"..tostring(self.state).."'\n"..
		"order = '"..tostring(self.order).."'\n"..
		"attack = "..tostring(self.attack).."\n"..
		"health = "..tostring(self.health).."\n"..
		"breath = "..tostring(self.breath).."\n"..
		"gotten = "..tostring(self.gotten).."\n"..
		"tamed = "..tostring(self.tamed).."\n"..
		"horny = "..tostring(self.horny).."\n"..
		"hornytimer = "..tostring(self.hornytimer).."\n"..
		"runaway_timer = "..tostring(self.runaway_timer).."\n"..
		"following = "..tostring(self.following)
	else
		tag = self.nametag
	end
	self.object:set_properties({
		nametag = tag,
	})

	self:update_roll()
end

local function shortest_term_of_yaw_rotatoin(self, rot_origin, rot_target, nums)
	if not rot_origin or not rot_target then
		return
	end

	rot_origin = math.deg(rot_origin)
	rot_target = math.deg(rot_target)

	if math.abs(rot_target - rot_origin) < 180 then
		return rot_target - rot_origin
	else
		if (rot_target - rot_origin) > 0 then
			return 360-(rot_target - rot_origin)
		else
			return (rot_target - rot_origin)+360
		end
	end
end


-- set and return valid yaw
function mob_class:set_yaw(yaw, delay, dtime)
	if self.noyaw then return end

	if self.state ~= PATHFINDING then
		self._turn_to = yaw
	end

	--mcl_log("Yaw is: \t\t" .. tostring(math.deg(yaw)))
	--mcl_log("self.object:get_yaw() is: \t" .. tostring(math.deg(self.object:get_yaw())))

	--clamp our yaw to a 360 range
	if math.deg(self.object:get_yaw()) > 360 then
		self.object:set_yaw(math.rad(1))
	elseif math.deg(self.object:get_yaw()) < 0 then
		self.object:set_yaw(math.rad(359))
	end

	--calculate the shortest way to turn to find our target
	local target_shortest_path = shortest_term_of_yaw_rotatoin(self, self.object:get_yaw(), yaw, true)

	--turn in the shortest path possible toward our target. if we are attacking, don't dance.
	if (math.abs(target_shortest_path) > 50 and not self._kb_turn) and (self.attack and self.attack:get_pos() or self.following and self.following:get_pos()) then
		if self.following then
			target_shortest_path = shortest_term_of_yaw_rotatoin(self, self.object:get_yaw(), minetest.dir_to_yaw(vector.direction(self.object:get_pos(), self.following:get_pos())), true)
		else
			target_shortest_path = shortest_term_of_yaw_rotatoin(self, self.object:get_yaw(), minetest.dir_to_yaw(vector.direction(self.object:get_pos(), self.attack:get_pos())), true)
		end
	end

	local ddtime = 0.05 --set_tick_rate

	if dtime then
		ddtime = dtime
	end

	if math.abs(target_shortest_path) > 280*ddtime then
		if target_shortest_path > 0 then
			self.object:set_yaw(self.object:get_yaw()+3.6*ddtime)
			if self.acc then
				self.acc=vector.rotate_around_axis(self.acc,vector.new(0,1,0), 3.6*ddtime)
			end
		else
			self.object:set_yaw(self.object:get_yaw()-3.6*ddtime)
			if self.acc then
				self.acc=vector.rotate_around_axis(self.acc,vector.new(0,1,0), -3.6*ddtime)
			end
		end
	end

	delay = delay or 0

	yaw = self.object:get_yaw()

	if delay == 0 then
		if self.shaking and dtime then
			yaw = yaw + (random() * 2 - 1) * 5 * dtime
		end
		self:update_roll()
		return yaw
	end

	self.target_yaw = yaw
	self.delay = delay

	return self.target_yaw
end

-- global function to set mob yaw
function mcl_mobs.yaw(self, yaw, delay, dtime)
	return mob_class.set_yaw(self, yaw, delay, dtime)
end

-- are we flying in what we are suppose to? (taikedz)
function mob_class:flight_check()

	local nod = self.standing_in
	local def = minetest.registered_nodes[nod]

	if not def then return false end -- nil check

	local fly_in
	if type(self.fly_in) == "string" then
		fly_in = { self.fly_in }
	elseif type(self.fly_in) == "table" then
		fly_in = self.fly_in
	else
		return false
	end

	for _,checknode in pairs(fly_in) do
		if nod == checknode or nod == "ignore" then
			return true
		end
	end

	return false
end

-- check if mob is dead or only hurt
function mob_class:check_for_death(cause, cmi_cause)

	if self.state == "die" then
		return true
	end

	-- has health actually changed?
	if self.health == self.old_health and self.health > 0 then
		return false
	end

	local damaged = self.health < self.old_health
	self.old_health = self.health

	-- still got some health?
	if self.health > 0 then

		-- make sure health isn't higher than max
		if self.health > self.hp_max then
			self.health = self.hp_max
		end

		-- play damage sound if health was reduced and make mob flash red.
		if damaged then
			add_texture_mod(self, "^[colorize:#d42222:175")
			minetest.after(1, function(self)
				if self and self.object then
					remove_texture_mod(self, "^[colorize:#d42222:175")
				end
			end, self)
			self:mob_sound("damage")
		end

		-- backup nametag so we can show health stats
		if not self.nametag2 then
			self.nametag2 = self.nametag or ""
		end

		if show_health
		and (cmi_cause and cmi_cause.type == "punch") then

			self.htimer = 2
			self.nametag = "♥ " .. self.health .. " / " .. self.hp_max

			self:update_tag()
		end

		return false
	end

	self:mob_sound("death")

	local function death_handle(self)
		-- dropped cooked item if mob died in fire or lava
		if cause == "lava" or cause == "fire" then
			item_drop(self, true, 0)
		else
			local wielditem = ItemStack()
			if cause == "hit" then
				local puncher = cmi_cause.puncher
				if puncher then
					wielditem = puncher:get_wielded_item()
				end
			end
			local cooked = mcl_burning.is_burning(self.object) or mcl_enchanting.has_enchantment(wielditem, "fire_aspect")
			local looting = mcl_enchanting.get_enchantment(wielditem, "looting")
			item_drop(self, cooked, looting)

			if ((not self.child) or self.type ~= "animal") and (minetest.get_us_time() - self.xp_timestamp <= 5000000) then
				mcl_experience.throw_xp(self.object:get_pos(), random(self.xp_min, self.xp_max))
			end
		end
	end

	-- execute custom death function
	if self.on_die then

		local pos = self.object:get_pos()
		local on_die_exit = self.on_die(self, pos, cmi_cause)
		if on_die_exit ~= true then
			death_handle(self)
		end

		if on_die_exit == true then
			self.state = "die"
			mcl_burning.extinguish(self.object)
			self.object:remove()
			return true
		end
	end

	local collisionbox
	if self.collisionbox then
		collisionbox = table.copy(self.collisionbox)
	end

	self.state = "die"
	self.attack = nil
	self.v_start = false
	self.fall_speed = DEFAULT_FALL_SPEED
	self.timer = 0
	self.blinktimer = 0
	remove_texture_mod(self, "^[colorize:#FF000040")
	remove_texture_mod(self, "^[brighten")
	self.passive = true

	self.object:set_properties({
		pointable = false,
		collide_with_objects = false,
	})

	set_velocity(self, 0)
	local acc = self.object:get_acceleration()
	acc.x, acc.y, acc.z = 0, DEFAULT_FALL_SPEED, 0
	self.object:set_acceleration(acc)

	local length
	-- default death function and die animation (if defined)
	if self.instant_death then
		length = 0
	elseif self.animation
	and self.animation.die_start
	and self.animation.die_end then

		local frames = self.animation.die_end - self.animation.die_start
		local speed = self.animation.die_speed or 15
		length = math.max(frames / speed, 0) + DEATH_DELAY
		set_animation(self, "die")
	else
		length = 1 + DEATH_DELAY
		set_animation(self, "stand", true)
	end


	-- Remove body after a few seconds and drop stuff
	local kill = function(self)
		if not self.object:get_luaentity() then
			return
		end

		death_handle(self)
		local dpos = self.object:get_pos()
		local cbox = self.collisionbox
		local yaw = self.object:get_rotation().y
		mcl_burning.extinguish(self.object)
		self.object:remove()
		mcl_mobs.death_effect(dpos, yaw, cbox, not self.instant_death)
	end
	if length <= 0 then
		kill(self)
	else
		minetest.after(length, kill, self)
	end

	return true
end

-- environmental damage (water, lava, fire, light etc.)
function mob_class:do_env_damage()

	-- feed/tame text timer (so mob 'full' messages dont spam chat)
	if self.htimer > 0 then
		self.htimer = self.htimer - 1
	end

	-- reset nametag after showing health stats
	if self.htimer < 1 and self.nametag2 then

		self.nametag = self.nametag2
		self.nametag2 = nil

		self:update_tag()
	end

	local pos = self.object:get_pos()

	self.time_of_day = minetest.get_timeofday()

	-- remove mob if beyond map limits
	if not within_limits(pos, 0) then
		mcl_burning.extinguish(self.object)
		self.object:remove()
		return true
	end

	-- Deal light damage to mob, returns true if mob died
	local function deal_light_damage(self, pos, damage)
		if not ((mcl_weather.rain.raining or mcl_weather.state == "snow") and mcl_weather.is_outdoor(pos)) then
			self.health = self.health - damage

			effect(pos, 5, "mcl_particles_smoke.png")

			if self:check_for_death("light", {type = "light"}) then
				return true
			end
		end
	end

	local sunlight = 10
	if within_limits(pos,0) then
		sunlight = minetest.get_natural_light(pos, self.time_of_day)
	end

	-- bright light harms mob
	if self.light_damage ~= 0 and (sunlight or 0) > 12 then
		if deal_light_damage(self, pos, self.light_damage) then
			return true
		end
	end
	local _, dim = mcl_worlds.y_to_layer(pos.y)
	if (self.sunlight_damage ~= 0 or self.ignited_by_sunlight) and (sunlight or 0) >= minetest.LIGHT_MAX and dim == "overworld" then
		if self.armor_list and not self.armor_list.helmet or not self.armor_list or self.armor_list and self.armor_list.helmet and self.armor_list.helmet == "" then
			if self.ignited_by_sunlight then
				mcl_burning.set_on_fire(self.object, 10)
			else
				deal_light_damage(self, pos, self.sunlight_damage)
				return true
			end
		end
	end

	local y_level = self.collisionbox[2]

	if self.child then
		y_level = self.collisionbox[2] * 0.5
	end

	-- what is mob standing in?
	pos.y = pos.y + y_level + 0.25 -- foot level
	local pos2 = {x=pos.x, y=pos.y-1, z=pos.z}
	self.standing_in = node_ok(pos, "air").name
	self.standing_on = node_ok(pos2, "air").name

	-- don't fall when on ignore, just stand still
	if self.standing_in == "ignore" then
		self.object:set_velocity({x = 0, y = 0, z = 0})
	end

	local nodef = minetest.registered_nodes[self.standing_in]

	-- rain
	if self.rain_damage > 0 then
		if mcl_weather.rain.raining and mcl_weather.is_outdoor(pos) then

			self.health = self.health - self.rain_damage

			if self:check_for_death("rain", {type = "environment",
					pos = pos, node = self.standing_in}) then
				return true
			end
		end
	end

	pos.y = pos.y + 1 -- for particle effect position

	-- water damage
	if self.water_damage > 0
	and nodef.groups.water then

		if self.water_damage ~= 0 then

			self.health = self.health - self.water_damage

			effect(pos, 5, "mcl_particles_smoke.png", nil, nil, 1, nil)

			if self:check_for_death("water", {type = "environment",
					pos = pos, node = self.standing_in}) then
				return true
			end
		end

	-- lava damage
	elseif self.lava_damage > 0
	and (nodef.groups.lava) then

		if self.lava_damage ~= 0 then

			self.health = self.health - self.lava_damage

			effect(pos, 5, "fire_basic_flame.png", nil, nil, 1, nil)
			mcl_burning.set_on_fire(self.object, 10)

			if self:check_for_death("lava", {type = "environment",
					pos = pos, node = self.standing_in}) then
				return true
			end
		end

	-- fire damage
	elseif self.fire_damage > 0
	and (nodef.groups.fire) then

		if self.fire_damage ~= 0 then

			self.health = self.health - self.fire_damage

			effect(pos, 5, "fire_basic_flame.png", nil, nil, 1, nil)
			mcl_burning.set_on_fire(self.object, 5)

			if self:check_for_death("fire", {type = "environment",
					pos = pos, node = self.standing_in}) then
				return true
			end
		end

	-- damage_per_second node check
	elseif nodef.damage_per_second ~= 0 and not nodef.groups.lava and not nodef.groups.fire then

		self.health = self.health - nodef.damage_per_second

		effect(pos, 5, "mcl_particles_smoke.png")

		if self:check_for_death("dps", {type = "environment",
				pos = pos, node = self.standing_in}) then
			return true
		end
	end

	-- Drowning damage
	if self.breath_max ~= -1 then
		local drowning = false
		if self.breathes_in_water then
			if minetest.get_item_group(self.standing_in, "water") == 0 then
				drowning = true
			end
		elseif nodef.drowning > 0 then
			drowning = true
		end
		if drowning then

			self.breath = math.max(0, self.breath - 1)

			effect(pos, 2, "bubble.png", nil, nil, 1, nil)
			if self.breath <= 0 then
				local dmg
				if nodef.drowning > 0 then
					dmg = nodef.drowning
				else
					dmg = 4
				end
				damage_effect(self, dmg)
				self.health = self.health - dmg
			end
			if self:check_for_death("drowning", {type = "environment",
					pos = pos, node = self.standing_in}) then
				return true
			end
		else
			self.breath = math.min(self.breath_max, self.breath + 1)
		end
	end

	--- suffocation inside solid node
	-- FIXME: Redundant with mcl_playerplus
	if (self.suffocation == true)
	and (nodef.walkable == nil or nodef.walkable == true)
	and (nodef.collision_box == nil or nodef.collision_box.type == "regular")
	and (nodef.node_box == nil or nodef.node_box.type == "regular")
	and (nodef.groups.disable_suffocation ~= 1)
	and (nodef.groups.opaque == 1) then

		-- Short grace period before starting to take suffocation damage.
		-- This is different from players, who take damage instantly.
		-- This has been done because mobs might briefly be inside solid nodes
		-- when e.g. climbing up stairs.
		-- This is a bit hacky because it assumes that do_env_damage
		-- is called roughly every second only.
		self.suffocation_timer = self.suffocation_timer + 1
		if self.suffocation_timer >= 3 then
			-- 2 damage per second
			-- TODO: Deal this damage once every 1/2 second
			self.health = self.health - 2

			if self:check_for_death("suffocation", {type = "environment",
					pos = pos, node = self.standing_in}) then
				return true
			end
		end
	else
		self.suffocation_timer = 0
	end

	return self:check_for_death("", {type = "unknown"})
end

function mob_class:damage_mob(reason,damage)
	if not self.health then return end
	damage = floor(damage)
	if damage > 0 then
		self.health = self.health - damage

		effect(self.object:get_pos(), 5, "mcl_particles_smoke.png", 1, 2, 2, nil)

		if self:check_for_death(reason, {type = reason}) then
			return true
		end
	end
end

function mob_class:check_entity_cramming()
	local p = self.object:get_pos()
	if not p then return end
	local oo = minetest.get_objects_inside_radius(p,1)
	local mobs = {}
	for _,o in pairs(oo) do
		local l = o:get_luaentity()
		if l and l.is_mob and l.health > 0 then table.insert(mobs,l) end
	end
	local clear = #mobs < ENTITY_CRAMMING_MAX
	local ncram = {}
	for _,l in pairs(mobs) do
		if l then
			if clear then
				l.cram = nil
			elseif l.cram == nil and not self.child then
				table.insert(ncram,l)
			elseif l.cram then
				l:damage_mob("cramming",CRAMMING_DAMAGE)
			end
		end
	end
	for i,l in pairs(ncram) do
		if i > ENTITY_CRAMMING_MAX then
			l.cram = true
		else
			l.cram = nil
		end
	end
end

-- falling and fall damage
-- returns true if mob died
function mob_class:falling(pos)

	if self.fly and self.state ~= "die" then
		return
	end

	if mcl_portals ~= nil then
		if mcl_portals.nether_portal_cooloff(self.object) then
			return false -- mob has teleported through Nether portal - it's 99% not falling
		end
	end

	-- floating in water (or falling)
	local v = self.object:get_velocity()

	if v.y > 0 then

		-- apply gravity when moving up
		self.object:set_acceleration({
			x = 0,
			y = DEFAULT_FALL_SPEED,
			z = 0
		})

	elseif v.y <= 0 and v.y > self.fall_speed then

		-- fall downwards at set speed
		self.object:set_acceleration({
			x = 0,
			y = self.fall_speed,
			z = 0
		})
	else
		-- stop accelerating once max fall speed hit
		self.object:set_acceleration({x = 0, y = 0, z = 0})
	end

	if minetest.registered_nodes[node_ok(pos).name].groups.lava then

		if self.floats_on_lava == 1 then

			self.object:set_acceleration({
				x = 0,
				y = -self.fall_speed / (math.max(1, v.y) ^ 2),
				z = 0
			})
		end
	end

	-- in water then float up
	if minetest.registered_nodes[node_ok(pos).name].groups.water then

		if self.floats == 1 then

			self.object:set_acceleration({
				x = 0,
				y = -self.fall_speed / (math.max(1, v.y) ^ 2),
				z = 0
			})
		end
	else

		-- fall damage onto solid ground
		if self.fall_damage == 1
		and self.object:get_velocity().y == 0 then
			local n = node_ok(vector.offset(pos,0,-1,0)).name
			local d = (self.old_y or 0) - self.object:get_pos().y

			if d > 5 and n ~= "air" and n ~= "ignore" then
				local add = minetest.get_item_group(self.standing_on, "fall_damage_add_percent")
				local damage = d - 5
				if add ~= 0 then
					damage = damage + damage * (add/100)
				end
				self:damage_mob("fall",damage)
			end

			self.old_y = self.object:get_pos().y
		end
	end
end
