local mod_storage = minetest.get_mod_storage()
--[[
Mod storage!
key = int
wher key is the player name, and int is 1 for enabled and 2 for disabled
]]

minetest.register_privilege("pvp", "Can configure own PvP setting")

-- Private table
local pvptable = {}

-- Public table, containing global functions
pvpplus = {}

local S

if minetest.get_modpath(
	"intllib"
) then
	S = intllib.Getter(
	)
else
	S = function(
		translated
	)
		return translated
	end
end

local function add_pvp_hud(player, state)
	local player_name = player:get_player_name()
	if state then
		pvptable[player_name].pvpenabled = player:hud_add({
			hud_elem_type = "text",
			position = {x = 1, y = 0},
			offset = {x=-125, y = 20},
			scale = {x = 100, y = 100},
			text = S("PvP is enabled for you!"),
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
			text = S("PvP is disabled for you!"),
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
end

function pvpplus.pvp_set(player_name, state)
	if pvpplus.is_playing_tournament(player_name) then
		return false, S("PvP state cannot be changed while playing a tournament.")
	end
	if type(state) ~= "boolean" then
		return false, S("The state parameter has to be a boolean.")
	end

	local player = minetest.get_player_by_name(player_name)
	if not player then
		return false, string.format(S("Player %s does not exist or is not currently connected."), player_name)
	end
	pvptable[player_name].state = state
	mod_storage:set_int(player_name, state and 1 or 2)

	minetest.chat_send_player(player_name, ((state and S("Your PvP has been enabled")) or S("Your PvP has been disabled")))

	player:hud_remove((state and pvptable[player_name].pvpdisabled) or pvptable[player_name].pvpenabled)
	player:hud_remove((state and pvptable[player_name].nopvppic) or pvptable[player_name].pvppic)

	add_pvp_hud(player, state)

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

if minetest.get_modpath("unified_inventory") then
	unified_inventory.register_button("pvp", {
		type = "image",
		image = "pvp.png",
		tooltip = "PvP",
		condition = function(player)
			return minetest.check_player_privs(player, "pvp")
		end,
		action = function(player)
			pvpplus.pvp_toggle(player:get_player_name())
		end
	})
end

minetest.register_chatcommand("pvp_enable", {
	params = "",
	description = S("Enables PvP"),
	privs = {
		pvp = true
	},
	func = function(name, param)
		if pvpplus.is_pvp(name) then
			return false, S("Your PvP is already enabled.")
		end
		return pvpplus.pvp_enable(name)
	end
})
minetest.register_chatcommand("pvp_disable", {
	params = "",
	description = S("Disables PvP"),
	privs = {
		pvp = true
	},
	func = function(name, param)
		if not pvpplus.is_pvp(name) then
			return false, S("Your PvP is already disabled.")
		end
		return pvpplus.pvp_disable(name)
	end
})

------ Load tournaments ------
dofile(minetest.get_modpath(minetest.get_current_modname()).."/tournament.lua")
------------------------------

-- Make these functions private
local tournament_on_punchplayer = pvpplus.tournament_on_punchplayer
pvpplus.tournament_on_punchplayer = nil


minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local state = mod_storage:get_int(player:get_player_name())
	if state == 0 then
		state = minetest.settings:get_bool("pvpplus.default_pvp_state") or false
	else
		state = state == 1
	end

	pvptable[name] = {state = state}

	add_pvp_hud(player, state)
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if not hitter:is_player() then
		return false
	end

	tournament_on_punchplayer(player, hitter, damage)

	local localname = player:get_player_name()
	local hittername = hitter:get_player_name()

	if not pvptable[localname].state then
		minetest.chat_send_player(hittername, string.format(S("You can't hit %s because their PvP is disabled."), localname))
		return true
	end
	if not pvptable[hittername].state then
		minetest.chat_send_player(hittername, string.format(S("You can't hit %s because your PvP is disabled."), hittername))
		return true
	end
	return false
end)
