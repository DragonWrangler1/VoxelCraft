--Based on:
--https://www.digminecraft.com/game_commands/title_command.php
--https://youtu.be/oVrtQRO2hpY

--TODO: use SSCSM to reduce lag and network trafic (just send modchannel messages)
--TODO: fadeIn and fadeOut animation (needs engine change: SSCSM or native support)
--TODO: allow obfuscating text (needs engine change: SSCSM or native support)
--TODO: allow colorizing and styling of part of the text (NEEDS ENGINE CHANGE!!!)
--TODO: exactly mc like layout

--Note that the table storing timeouts use playername as index insteed of player objects (faster)
--This is intended in order to speedup the process of removing HUD elements the the timeout is up

local huds_idx = {}
local hud_hide_timeouts = {}

-- TODO: when < minetest 5.9 isn't supported anymore, remove this variable check and replace all occurences of [hud_elem_type_field] with type
local hud_elem_type_field = "type"
if not minetest.features.hud_def_type_field then
	hud_elem_type_field = "hud_elem_type"
end

hud_hide_timeouts.title = {}
hud_hide_timeouts.subtitle = {}
hud_hide_timeouts.actionbar = {}

huds_idx.title = {}
huds_idx.subtitle = {}
huds_idx.actionbar = {}

vlc_title = {}
vlc_title.defaults = { fadein = 10, stay = 70, fadeout = 20 }
vlc_title.layout = {}
vlc_title.layout.title = { position = { x = 0.5, y = 0.5 }, alignment = { x = 0, y = -1.3 }, size = 7 }
vlc_title.layout.subtitle = { position = { x = 0.5, y = 0.5 }, alignment = { x = 0, y = 1.7 }, size = 4 }
vlc_title.layout.actionbar = { position = { x = 0.5, y = 1 }, alignment = { x = 0, y = 0 }, size = 1 }

local function gametick_to_secondes(gametick)
	if gametick then
		return gametick / 20
	else
		return nil
	end
end

--https://github.com/minetest/minetest/blob/b3b075ea02034306256b486dd45410aa765f035a/doc/lua_api.txt#L8477

local function style_to_bits(bold, italic)
	if bold then
		if italic then
			return 3
		else
			return 1
		end
	else
		if italic then
			return 2
		else
			return 0
		end
	end
end

local no_style = style_to_bits(false, false)

---PARAMS SYSTEM
local player_params = {}

minetest.register_on_joinplayer(function(player)
	--local playername = player:get_player_name()
	player_params[player] = {
		stay = vlc_title.defaults.stay,
		--fadeIn = vlc_title.defaults.fadein,
		--fadeOut = vlc_title.defaults.fadeout,
	}
	local _, hex_color = vlc_util.get_color("white")
	huds_idx.title[player] = player:hud_add({
		[hud_elem_type_field] = "text",
		position      = vlc_title.layout.title.position,
		alignment     = vlc_title.layout.title.alignment,
		text          = "",
		style         = no_style,
		size          = { x = vlc_title.layout.title.size },
		number        = hex_color,
		z_index       = 100,
	})
	huds_idx.subtitle[player] = player:hud_add({
		[hud_elem_type_field] = "text",
		position      = vlc_title.layout.subtitle.position,
		alignment     = vlc_title.layout.subtitle.alignment,
		text          = "",
		style         = no_style,
		size          = { x = vlc_title.layout.subtitle.size },
		number        = hex_color,
		z_index       = 100,
	})
	huds_idx.actionbar[player] = player:hud_add({
		[hud_elem_type_field] = "text",
		position      = vlc_title.layout.actionbar.position,
		offset        = { x = 0, y = -210 },
		alignment     = vlc_title.layout.actionbar.alignment,
		style         = no_style,
		text          = "",
		size          = { x = vlc_title.layout.actionbar.size },
		number        = hex_color,
		z_index       = 100,
	})
end)

minetest.register_on_leaveplayer(function(player)
	local playername = player:get_player_name()

	--remove player params from the list
	player_params[player] = nil

	--remove HUD idx from the list (HUD elements are removed by the engine)
	huds_idx.title[player] = nil
	huds_idx.subtitle[player] = nil
	huds_idx.actionbar[player] = nil

	--remove timers from list
	hud_hide_timeouts.title[playername] = nil
	hud_hide_timeouts.subtitle[playername] = nil
	hud_hide_timeouts.actionbar[playername] = nil
end)

function vlc_title.params_set(player, data)
	player_params[player] = {
		stay = data.stay or vlc_title.defaults.stay,
		--fadeIn = data.fadeIn or vlc_title.defaults.fadein,
		--fadeOut = data.fadeOut or vlc_title.defaults.fadeout,
	}
end

function vlc_title.params_get(player)
	return player_params[player]
end

--API FUNCTIONS
function vlc_title.set(player, type, data)
	if not data.color then
		data.color = "white"
	end
	local _, hex_color = vlc_util.get_color(data.color)
	if not hex_color then
		return false
	end

	player:hud_change(huds_idx[type][player], "text", data.text)
	player:hud_change(huds_idx[type][player], "number", hex_color)

	-- Apply bold and italic
	player:hud_change(huds_idx[type][player], "style", style_to_bits(data.bold, data.italic))

	hud_hide_timeouts[type][player:get_player_name()] = gametick_to_secondes(data.stay) or
		gametick_to_secondes(vlc_title.params_get(player).stay)

	return true
end

function vlc_title.remove(player, type)
	if player then
		player:hud_change(huds_idx[type][player], "text", "")
		player:hud_change(huds_idx[type][player], "style", no_style)
	end
end

function vlc_title.clear(player)
	vlc_title.remove(player, "title")
	vlc_title.remove(player, "subtitle")
	vlc_title.remove(player, "actionbar")
end

minetest.register_on_dieplayer(function(player)
	vlc_title.clear(player)
end)

minetest.register_globalstep(function(dtime)
	local new_timeouts = {
		title = {},
		subtitle = {},
		actionbar = {},
	}

	for element, content in pairs(hud_hide_timeouts) do
		for name, timeout in pairs(content) do
			timeout = timeout - dtime
			if timeout <= 0 then
				local player = minetest.get_player_by_name(name)
				vlc_title.remove(player, element)
			else
				new_timeouts[element][name] = timeout
			end
		end
	end

	hud_hide_timeouts = new_timeouts
end)


--DEBUG STUFF!!
--TODO:Proper /title command that can send the title to other players.
--These commands are just for debugging right now.
local dbg_msg = "Note that these are just debug commands right now. e.g. the title is only sent to he player issuing the command. Proper /title commands will be added in the future."
minetest.register_chatcommand("title", {
	privs = { debug = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			vlc_title.set(player, "title", { text = param, color = "gold", bold = true, italic = true })
			return true, dbg_msg
		else
			return false, dbg_msg
		end
	end,
})

minetest.register_chatcommand("subtitle", {
	privs = { debug = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			vlc_title.set(player, "subtitle", { text = param, color = "gold" })
			return true, dbg_msg
		else
			return false, dbg_msg
		end
	end,
})

minetest.register_chatcommand("actionbar", {
	privs = { debug = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			vlc_title.set(player, "actionbar", { text = param, color = "gold", bold = true, italic = true })
			return true, dbg_msg
		else
			return false, dbg_msg
		end
	end,
})

minetest.register_chatcommand("title_timeout", {
	privs = { debug = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			vlc_title.params_set(player, { stay = 600 })
			return true, dbg_msg
		else
			return false, dbg_msg
		end
	end,
})

minetest.register_chatcommand("title_all", {
	privs = { debug = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			vlc_title.params_set(player, { stay = 600 })
			vlc_title.set(player, "title", { text = param, color = "gold" })
			vlc_title.set(player, "subtitle", { text = param, color = "gold" })
			vlc_title.set(player, "actionbar", { text = param, color = "gold" })
			return true, dbg_msg
		else
			return false, dbg_msg
		end
	end,
})

minetest.register_chatcommand("title_all_styles", {
	privs = { debug = true },
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			vlc_title.params_set(player, { stay = 600 })
			vlc_title.set(player, "title", { text = param, color = "gold" })
			vlc_title.set(player, "subtitle", { text = param, color = "gold", bold = true })
			vlc_title.set(player, "actionbar", { text = param, color = "gold", italic = true })
			return true, dbg_msg
		else
			return false, dbg_msg
		end
	end,
})
