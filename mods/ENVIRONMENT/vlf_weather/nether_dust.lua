vlf_weather.nether_dust = {}
vlf_weather.nether_dust.particlespawners = {}

local enable_nether_dust = minetest.settings:get_bool("vlf_nether_dust", true)
local PARTICLES_COUNT_NETHER_DUST = 150

local psdef= {
	amount = PARTICLES_COUNT_NETHER_DUST,
	time = 0,
	minpos = vector.new(-15,-15,-15),
	maxpos =vector.new(15,15,15),
	minvel = vector.new(-0.3,-0.15,-1),
	maxvel = vector.new(0.3,0.15,0.3),
	minacc = vector.new(-1,-0.4,-1),
	maxacc = vector.new(1,0.4,1),
	minexptime = 1,
	maxexptime = 10,
	minsize = 0.2,
	maxsize = 0.7,
	collisiondetection = false,
	collision_removal = false,
	object_collision = false,
	vertical = false
}

vlf_weather.nether_dust.add_particlespawners = function(player)
	if not enable_nether_dust then
		return
	end

	local name=player:get_player_name()
	vlf_weather.nether_dust.particlespawners[name]={}
	psdef.playername = name
	psdef.attached = player
	psdef.glow = math.random(0,minetest.LIGHT_MAX)
	for i=1,3 do
		psdef.texture="vlf_particles_nether_dust"..i..".png"
		vlf_weather.nether_dust.particlespawners[name][i]=minetest.add_particlespawner(psdef)
	end
end

vlf_weather.nether_dust.delete_particlespawners = function(player)
	local name=player:get_player_name()
	if vlf_weather.nether_dust.particlespawners[name] then
		for i=1,3 do
			minetest.delete_particlespawner(vlf_weather.nether_dust.particlespawners[name][i])
		end
		vlf_weather.nether_dust.particlespawners[name]=nil
	end
end

local function update_player_particles(player)
	if not vlf_worlds.has_dust(player:get_pos()) then
		vlf_weather.nether_dust.delete_particlespawners(player)
	elseif not vlf_weather.nether_dust.particlespawners[player:get_player_name()] then
		vlf_weather.nether_dust.add_particlespawners(player)
	end
end

vlf_worlds.register_on_dimension_change(update_player_particles)
minetest.register_on_joinplayer(update_player_particles)

minetest.register_on_leaveplayer(function(player)
	vlf_weather.nether_dust.delete_particlespawners(player)
end)
