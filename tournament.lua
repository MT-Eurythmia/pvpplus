local previous_player_transfer_distance

pvpplus.tournament = {
	engaging_players = false,
	engagement_position = nil,
	running_tournament = false,
	teleport_immediately = false,
	engaged_players = {},
	previous_pvp_states = {},
	players = {},
	sent_damages = {},
	received_damages = {},
	kills = {},
	sound_handles = {},
	starting_infos = {starter = nil, open_time = nil, start_time = nil, initially_engaged_players = nil},
	broadcast_messages = false,
	damage_motionless = false,
	motion_table = {},
}

local tournament = pvpplus.tournament -- Shortcut reference

function pvpplus.engage_player(player_name)
	if not tournament.engaging_players then
		return false, "There is no open tournament."
	end
	tournament.engaged_players[player_name] = true
	minetest.chat_send_player(player_name, "You have been engaged for a PvP tournament!")

	if tournament.engagement_position and tournament.teleport_immediately then
		local player_obj = minetest.get_player_by_name(player_name)
		player_obj:moveto(tournament.engagement_position)
		-- Send a chat message
		minetest.chat_send_player(player_name, "You've been teleported to the tournament position.")
	end
	return true
end

function pvpplus.disengage_player(player_name)
	if not pvpplus.is_engaged(player_name) then
		return false, "This player is not engaged"
	end
	tournament.engaged_players[player_name] = nil
	return true
end

function pvpplus.is_engaged(player_name)
	if tournament.engaged_players[player_name] then
		return true
	else
		return false
	end
end

function pvpplus.is_engaging_players()
	return tournament.engaging_players
end

function pvpplus.get_score(name)
	if not pvpplus.is_running_tournament() then
		return false, "There is no running tournament."
	end
	if not tournament.sent_damages[name] then
		return false, "Player " .. name .. " did not play in the current tournament."
	end
	return tournament.sent_damages[name] - tournament.received_damages[name] + tournament.kills[name] * 20
end

function pvpplus.chat_send_tournament(msg, allow_broadcast)
	if tournament.broadcast_messages and allow_broadcast then
		minetest.chat_send_all(msg)
		return false
	elseif pvpplus.is_running_tournament() then
		for name, _ in pairs(tournament.sent_damages) do
			minetest.chat_send_player(name, msg)
		end
		return true
	elseif pvpplus.is_engaging_players() then
		for name, _ in pairs(tournament.engaged_players) do
			minetest.chat_send_player(name, msg)
		end
		return true
	else
		return false
	end
end

function pvpplus.start_tournament()
	if tournament.running_tournament then
		return false, "There is already a running tournament."
	end

	local count = 0
	for _, _ in pairs(tournament.engaged_players) do
		count = count + 1
	end
	if count <= 1 and not pvpplus.debug then
		pvpplus.chat_send_tournament("There are not enough engaged players to start a tournament.", true)
		tournament.engaged_players = {}
		tournament.engagement_position = nil
		tournament.teleport_immediately = false
		tournament.engaging_players = false
		return false
	end

	-- Stop engaging
	tournament.engaging_players = false

	local chat_message = "PVP TOURNAMENT BEGINS! Started by " .. (tournament.starting_infos.starter or "[unknown player]") .. "\nEngaged players: "
	tournament.starting_infos.initially_engaged_players = {}

	for player, _ in pairs(tournament.engaged_players) do
		tournament.starting_infos.initially_engaged_players[player] = true

		-- Enable PvPs
		tournament.previous_pvp_states[player] = pvpplus.is_pvp(player)
		pvpplus.pvp_enable(player)
		-- Move to the playing table
		tournament.players[player] = true
		tournament.sent_damages[player] = 0
		tournament.received_damages[player] = 0
		tournament.kills[player] = 0
		tournament.motion_table[player] = {pos = minetest.get_player_by_name(player):get_pos(), time = os.time()}

		chat_message = chat_message .. player .. ", "

		-- Play the sounds
		minetest.sound_play("pvpplus_tournament_start", {
			to_player = player,
			gain = 1.0,
		})
		if minetest.setting_getbool("pvpplus.enable_sound_loop") ~= false then -- If it's true or nil (unset)
			minetest.after(10, function(name)
				tournament.sound_handles[name] = minetest.sound_play("pvpplus_tournament_loop", {
					to_player = name,
					gain = 1.0,
					loop = true,
				})
			end, player)
		end
	end
	chat_message = chat_message:sub(0, -3) -- Remove the last ', '
	tournament.engaged_players = {}
	tournament.engagement_position = nil
	tournament.teleport_immediately = false

	-- Set the player transfer distance
	previous_player_transfer_distance = minetest.setting_get("player_transfer_distance")
	minetest.setting_set("player_transfer_distance", 0) -- 0 = unlimited

	-- Send the final chat message
	pvpplus.chat_send_tournament(chat_message, true)

	-- Set the tournament flag
	tournament.running_tournament = true

	-- Update HUDs
	pvpplus.tournament_hud_update_all()
end

function pvpplus.start_global_tournament(starter_name)
	local players = minetest.get_connected_players()

	-- Engage all connected players
	pvpplus.allow_engaging(starter_name)
	for _, player in ipairs(players) do
		local player_name = player:get_player_name()
		if minetest.get_player_privs(player_name).interact then -- Well, don't engage players who don't have interact.
			pvpplus.engage_player(player_name)
		end
	end

	-- Start the tournament
	return pvpplus.start_tournament()
end

function pvpplus.stop_tournament()
	if not pvpplus.is_running_tournament() then
		return false
	end

	pvpplus.chat_send_tournament("END OF TOURNAMENT!", true)

	-- Calculate rating
	local rating = {}
	for name, _ in pairs(tournament.sent_damages) do
		table.insert(rating, {
			name = name,
			score = pvpplus.get_score(name)
		})

		if tournament.sound_handles[name] then
			minetest.sound_stop(tournament.sound_handles[name])
		end
		minetest.sound_play("pvpplus_tournament_end", {
			to_player = name,
			gain = 1.0,
		})

		-- Set PvP to the state it had before the tournament
		if tournament.previous_pvp_states[name] then
			pvpplus.pvp_set(name, tournament.previous_pvp_states[name])
		end

		local player = minetest.get_player_by_name(name)
		if player then
			pvpplus.tournament_hud_clear(player)
		end
	end
	table.sort(rating, function(a, b) return a.score > b.score end)

	-- Print it
	-- It won't look good if the font used in the chat and the formspec textarea isn't monospace.
	local str = "***************************** TOURNAMENT RANKING ****************************\n" ..
	            "+--------------+-------+--------+---------------+-------------------+-------+\n" ..
		    "| player       | rank  | score  | sent damages  | received damages  | kills |\n" ..
	            "+--------------+-------+--------+---------------+-------------------+-------+"
	for i, v in ipairs(rating) do
		local player = v.name
		local rank = tostring(i)
		local score = tostring(v.score)
		local sent_damages = tostring(tournament.sent_damages[v.name])
		local received_damages = tostring(tournament.received_damages[v.name])
		local kills = tostring(tournament.kills[v.name])

		local substr = "| "

		local function cat_str(value, len)
			substr = substr .. value
			if #substr > len then
				substr = substr:sub(1, len-1) .. "+"
			end
			for n = #substr, len do
				substr = substr .. " "
			end
			substr = substr .. "| "
		end

		cat_str(player, 14)
		cat_str(rank, 22)
		cat_str(score, 31)
		cat_str(sent_damages, 47)
		cat_str(received_damages, 67)
		cat_str(kills, 75)

		str = str .. "\n" .. substr
	end
	str = str .. "\n+--------------+-------+--------+---------------+-------------------+-------+"

	pvpplus.chat_send_tournament(str, true)

	local formspec = "size[10,8.5]textarea[0.5,0.5;9.5,8;ranking;Ranking;"..str.."]button_exit[4,7.5;2,1;exit;Ok]"
	for name, _ in pairs(tournament.sent_damages) do
		minetest.show_formspec(name, "pvpplus:ranking", formspec)
	end

	-- Clean tables
	tournament = {
		engaging_players = false,
		running_tournament = false,
		engaged_players = {},
		previous_pvp_states = {},
		players = {},
		sent_damages = {},
		received_damages = {},
		kills = {},
		sound_handles = {},
		starting_infos = {starter = nil, open_time = nil, start_time = nil, initially_engaged_players = nil},
		broadcast_messages = false,
		damage_motionless = false,
		motion_table = {},
	}

	-- Change the player transfer distance back
	minetest.setting_set("player_transfer_distance", previous_player_transfer_distance)
end

function pvpplus.allow_engaging(starter_name, teleport)
	if tournament.engaging_players then
		return false, "There is already an open tournament."
	end
	if tournament.is_running_tournament then
		return false, "There is already a running tournament."
	end
	tournament.engaging_players = true
	minetest.chat_send_all(starter_name .. " opened a tournament! Type /engage to engage yourself in the tournament!")
	if teleport then
		tournament.engagement_position = minetest.get_player_by_name(starter_name):get_pos()
	end
	minetest.sound_play("pvpplus_tournament_start", {
		gain = 1.0,
	})
	return true
end

function pvpplus.teleport_engaged_players()
	if not tournament.engagement_position then
		return false, "No engagement position."
	end
	for player, _ in pairs(tournament.engaged_players) do
		-- Teleport player to the starter
		if tournament.engagement_position then
			local player_obj = minetest.get_player_by_name(player)
			player_obj:moveto(tournament.engagement_position)
		end
		-- Send a chat message
		minetest.chat_send_player(player, "You've been teleported to the tournament position.")
	end
	tournament.teleport_immediately = true
	return true
end

function pvpplus.remove_from_tournament(player_name)
	-- Remove from players table
	tournament.players[player_name] = nil

	-- Send a chat message
	if minetest.get_player_by_name(player_name) then
		minetest.chat_send_player(player_name, "You are no longer playing the tournament.")
	end
	pvpplus.chat_send_tournament("Player "..player_name.." is no longer playing the tournament.")

	-- Change their PvP state
	pvpplus.pvp_set(player_name, tournament.previous_pvp_states[player_name])
	tournament.previous_pvp_states[player_name] = nil

	-- Check if the tournament is ended
	local count = 0
	for _, _ in pairs(tournament.players) do count = count + 1 end

	if count <= 1 then -- 1 or less remaining players
		pvpplus.stop_tournament()
	else
		pvpplus.tournament_hud_update_all()
	end
end

function pvpplus.add_to_tournament(player_name)
	local player = minetest.get_player_by_name(player_name)
	if not pvpplus.is_running_tournament() or pvpplus.is_playing_tournament(player_name) or not player then
		return false
	end

	-- Add to tables
	tournament.players[player_name] = true
	tournament.sent_damages[player_name] = 0
	tournament.received_damages[player_name] = 0
	tournament.kills[player_name] = 0
	tournament.previous_pvp_states[player_name] = pvpplus.is_pvp(player_name)
	tournament.motion_table[player] = {pos = minetest.get_player_by_name(player):get_pos(), time = os.time()}

	-- Enable PvP
	pvpplus.pvp_enable(player_name)

	-- Send a chat message
	minetest.chat_send_player(player_name, "You joined the current tournament!")
	pvpplus.chat_send_tournament("Player "..player_name.." joined the current tournament!")

	pvpplus.tournament_hud_update_all()
end

function pvpplus.is_playing_tournament(player_name)
	if tournament.players[player_name] then
		return true
	else
		return false
	end
end

function pvpplus.get_tournament_players()
	local t = {}
	if pvpplus.is_running_tournament() then
		for name, _ in pairs(tournament.players) do
			table.insert(t, minetest.get_player_by_name(name))
		end
	elseif pvpplus.is_engaging_players() then
		for name, _ in pairs(tournament.engaged_players) do
			table.insert(t, minetest.get_player_by_name(name))
		end
	else
		t = nil
	end

	return t
end

function pvpplus.is_running_tournament()
	return tournament.running_tournament
end

function pvpplus.tournament_on_punchplayer(player, hitter, damage)
	local player_name = player:get_player_name()
	local hitter_name = hitter:get_player_name()

	if not (pvpplus.is_running_tournament()
	    and pvpplus.is_playing_tournament(player_name)
	    and pvpplus.is_playing_tournament(hitter_name)) then
		return false
	end

	tournament.received_damages[player_name] = tournament.received_damages[player_name] + damage
	tournament.sent_damages[hitter_name] = tournament.sent_damages[hitter_name] + damage

	if player:get_hp() - damage <= 0 then -- Killed
		tournament.kills[hitter_name] = tournament.kills[hitter_name] + 1
		minetest.chat_send_player(player_name, "You have been killed by " .. hitter_name)
		-- Removing the player from the tournament and updating HUDs is done by the on_dieplayer callback.
	else
		pvpplus.tournament_hud_update_all()
	end
end

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	if pvpplus.is_playing_tournament(player_name) then
		pvpplus.remove_from_tournament(player_name)
	end
	if pvpplus.is_engaged(player_name) then
		pvpplus.disengage_player(player_name)
	end
end)

minetest.register_on_dieplayer(function(player)
	local player_name = player:get_player_name()
	if not pvpplus.is_playing_tournament(player_name) then
		return
	end

	pvpplus.remove_from_tournament(player_name)

	local pos = vector.round(player:getpos())
	if minetest.get_modpath("bones") and minetest.get_node(pos).name == "bones:bones" then
		local bones_inv = minetest.get_inventory({type="node", pos=pos})
		local player_inv = player:get_inventory()
		if not player_inv:is_empty("main") then
			minetest.chat_send_player(player_name, "Cannot give you back your stuff because your inventory is not empty. Your stuff is still is your bones.")
			return
		end
		player_inv:set_list("main", bones_inv:get_list("main"))
		minetest.remove_node(pos)
	end
end)

dofile(minetest.get_modpath(minetest.get_current_modname()).."/tournament_commands.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/tournament_hud.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/tournament_motionless.lua")
