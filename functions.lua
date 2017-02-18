-- Private table
local pvptable = {}

-- Public table, containing global functions
pvpplus = {}

function pvpplus.pvp_enable(player_name)
	if pvpplus.is_playing_tournament(player_name) then
		return false, "PvP state cannot be changed while playing a tournament."
	end

	local player = minetest.get_player_by_name(player_name)

	pvptable[player_name] = true

	minetest.chat_send_player(player_name, "You PvP has been enabled")

	player:hud_remove(pvpdisabled)
	player:hud_remove(nopvppic)

	pvpenabled = player:hud_add({
		hud_elem_type = "text",
		position = {x = 1, y = 0},
		offset = {x=-125, y = 20},
		scale = {x = 100, y = 100},
		text = "PvP is enabled for you!",
		number = 0xFF0000 -- Red
	})
	pvppic = player:hud_add({
		hud_elem_type = "image",
		position = {x = 1, y = 0},
		offset = {x=-210, y = 20},
		scale = {x = 1, y = 1},
		text = "pvp.png"
	})

	return true
end

function pvpplus.pvp_disable(player_name)
	if pvpplus.is_playing_tournament(player_name) then
		return false, "PvP state cannot be changed while playing a tournament."
	end

	player = minetest.get_player_by_name(player_name)

	pvptable[player_name] = false

	minetest.chat_send_player(player_name, "Your PvP has been disabled")

	player:hud_remove(pvpenabled)
	player:hud_remove(pvppic)

	pvpdisabled = player:hud_add({
		hud_elem_type = "text",
		position = {x = 1, y = 0},
		offset = {x=-125, y = 20},
		scale = {x = 100, y = 100},
		text = "PvP is disabled for you!",
		number = 0x7DC435
	})
	nopvppic = player:hud_add({
		hud_elem_type = "image",
		position = {x = 1, y = 0},
		offset = {x = -210, y = 20},
		scale = {x = 1, y = 1},
		text = "nopvp.png"
	})

	return true
end

function pvpplus.pvp_toggle(playername)
	if pvptable[playername] then
		return pvpplus.pvp_disable(playername)
	else
		return pvpplus.pvp_enable(playername)
	end
end

unified_inventory.register_button("pvp", {
	type = "image",
	image = "pvp.png",
	action = function(player)
		pvpplus.pvp_toggle(player:get_player_name())
	end
})

dofile(minetest.get_modpath(minetest.get_current_modname()).."/tournament.lua")
-- Make these functions private
local tournament_on_punchplayer = pvpplus.tournament_on_punchplayer
pvpplus.tournament_on_punchplayer = nil

minetest.register_on_joinplayer(function(player)
	nopvppic = player:hud_add({
		hud_elem_type = "image",
		position = {x = 1, y = 0},
		offset = {x = -210, y = 20},
		scale = {x = 1, y = 1},
		text = "nopvp.png"
	})

	pvpdisabled = player:hud_add({
		hud_elem_type = "text",
		position = {x = 1, y = 0},
		offset = {x=-125, y = 20},
		scale = {x = 100, y = 100},
		text = "PvP is disabled for you!",
		number = 0x7DC435
	})

	localname = player:get_player_name()
	pvptable[localname] = false
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if not hitter:is_player() then
		return false
	end

	tournament_on_punchplayer(player, hitter, damage)

	local localname = player:get_player_name()
	local hittername = hitter:get_player_name()

	if pvptable[localname] and pvptable[hittername] then
		return false
	else
		minetest.chat_send_player(hittername, "The player "..localname.." does not have PvP activated.")
		return true
	end
end)
