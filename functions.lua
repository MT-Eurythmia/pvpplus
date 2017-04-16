-- Private table
local pvptable = {}

-- Public table, containing global functions
pvpplus = {}

function pvpplus.pvp_set(player_name, state)
	if type(state) ~= "boolean" then
		return false, "The state parameter has to be a boolean."
	end

	local player = minetest.get_player_by_name(player_name)
	if not player then
		return false, "Player " .. player_name .. " does not exist or is not currently connected."
	end
	pvptable[player_name].state = state

	minetest.chat_send_player(player_name, "Your PvP has been " .. ((state and "enabled") or "disabled"))

	player:hud_remove((state and pvptable[player_name].pvpdisabled) or pvptable[player_name].pvpenabled)
	player:hud_remove((state and pvptable[player_name].nopvppic) or pvptable[player_name].pvppic)

	if state then
		pvptable[player_name].pvpenabled = player:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 0},
			offset = {x=-125, y = 20},
			scale = {x = 100, y = 100},
			text = "PvP is enabled for you!",
			number = 0xFF0000 -- Red
		})
		pvptable[player_name].pvppic = player:hud_add({
			hud_elem_type = "image",
			position = {x = 1, y = 0},
			offset = {x=-210, y = 20},
			scale = {x = 1, y = 1},
			text = "pvp.png"
		})
	else
		pvptable[player_name].pvpdisabled = player:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 0},
			offset = {x=-125, y = 20},
			scale = {x = 100, y = 100},
			text = "PvP is disabled for you!",
			number = 0x7DC435
		})
		pvptable[player_name].nopvppic = player:hud_add({
			hud_elem_type = "image",
			position = {x = 1, y = 0},
			offset = {x = -210, y = 20},
			scale = {x = 1, y = 1},
			text = "nopvp.png"
		})
	end

	return true
end

function pvpplus.pvp_enable(player_name)
	return pvpplus.pvp_set(player_name, true)
end

function pvpplus.pvp_disable(player_name)
	return pvpplus.pvp_set(player_name, false)
end

function pvpplus.pvp_toggle(playername)
	if pvptable[playername].state then
		return pvpplus.pvp_disable(playername)
	else
		return pvpplus.pvp_enable(playername)
	end
end

function pvpplus.is_pvp(playername)
	return pvptable[playername].state or false
end

unified_inventory.register_button("pvp", {
	type = "image",
	image = "pvp.png",
	action = function(player)
		local player_name = player:get_player_name()
		if pvpplus.is_playing_tournament(player_name) then
			minetest.chat_send_player(player_name, "PvP state cannot be changed while playing a tournament.")
		else
			pvpplus.pvp_toggle(player_name)
		end
	end
})

dofile(minetest.get_modpath(minetest.get_current_modname()).."/tournament.lua")
-- Make these functions private
local tournament_on_punchplayer = pvpplus.tournament_on_punchplayer
pvpplus.tournament_on_punchplayer = nil

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	pvptable[name] = {state = false}
	pvptable[name].nopvppic = player:hud_add({
		hud_elem_type = "image",
		position = {x = 1, y = 0},
		offset = {x = -210, y = 20},
		scale = {x = 1, y = 1},
		text = "nopvp.png"
	})

	pvptable[name].pvpdisabled = player:hud_add({
		hud_elem_type = "text",
		position = {x = 1, y = 0},
		offset = {x=-125, y = 20},
		scale = {x = 100, y = 100},
		text = "PvP is disabled for you!",
		number = 0x7DC435
	})
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if not hitter:is_player() then
		return false
	end

	tournament_on_punchplayer(player, hitter, damage)

	local localname = player:get_player_name()
	local hittername = hitter:get_player_name()

	if not pvptable[localname].state then
		minetest.chat_send_player(hittername, "You can't hit "..localname.." because their PvP is disabled.")
		return true
	end
	if not pvptable[hittername].state then
		minetest.chat_send_player(hittername, "You can't hit "..localname.." because your PvP is disabled.")
		return true
	end
	return false
end)
