local tournament_starting_time = tonumber(minetest.setting_get("pvpplus.tournament_starting_time")) or 60 -- seconds
local tournament = pvpplus.tournament -- Shortcut reference

minetest.register_privilege("tournament_mod", "PvP Tournament Moderator")

local function check_permission(name)
	if minetest.get_player_privs(name).tournament_mod then
		return true
	end
	if (tournament.starting_infos.starter or "") == name then
		return true
	end
	return false
end

minetest.register_chatcommand("start_global_tournament", {
	params = "",
	description = "Start a PvP tournament engaging every connected players and starting immediately",
	privs = {interact = true, tournament_mod = true},
	func = function(name, param)
		-- Fill start infos
		tournament.starting_infos.starter = name
		tournament.starting_infos.open_time = nil
		tournament.starting_infos.start_time = os.time()

		return pvpplus.start_global_tournament(name)
	end
})

minetest.register_chatcommand("stop_tournament", {
	params = "",
	description = "Stops the current PvP tournament",
	privs = {interact = true},
	func = function(name, param)
		if not check_permission(name) then
			return false, "You have no permission to stop this tournament."
		end
		pvpplus.stop_tournament()
		return true
	end
})

minetest.register_chatcommand("remove_from_tournament", {
	params = "<name>",
	description = "Removes a player from a PvP tournament",
	privs = {interact = true},
	func = function(name, param)
		if not check_permission(name) then
			return false, "You have no permission to remove a player from this tournament."
		end
		if not minetest.get_player_by_name(param) then
			return false, "Player does not exist. Please refer to usage: /help kick_from_tournament"
		end
		minetest.chat_send_player(param, "You have been removed from the tournament by " .. name)
		pvpplus.remove_from_tournament(param)
	end
})

minetest.register_chatcommand("add_to_tournament", {
	params = "<name>",
	description = "Adds a player to the current tournament",
	privs = {interact = true},
	func = function(name, param)
		if not check_permission(name) then
			return false, "You have no permission to add a player to this tournament."
		end
		if not minetest.get_player_by_name(param) then
			return false, "Player does not exist. Please refer to usage: /help kick_from_tournament"
		end
		if pvpplus.is_playing_tournament(player) then
			return false, "Player is already playing a tournament."
		end
		if not pvpplus.is_running_tournament() then
			return false, "There is no currently running tournament."
		end
		minetest.chat_send_player(param, "You have been added to the current tournament by " .. name)
		pvpplus.add_to_tournament(param)
	end
})

minetest.register_chatcommand("leave_tournament", {
	params = "",
	description = "Leaves a PvP tournament",
	privs = {interact = true},
	func = function(name, param)
		if not pvpplus.is_playing_tournament(name) then
			return false, "You are not playing a tournament."
		end
		pvpplus.remove_from_tournament(name)
	end
})

minetest.register_chatcommand("engage", {
	params = "",
	description = "Engages for the next PvP tournament",
	privs = {interact = true},
	func = function(name, param)
		if pvpplus.is_playing_tournament(name) then
			return false, "You are already playing a tournament."
		end
		if not tournament.engaging_players then
			return false, "There is no opened tournament. Type /tournament!"
		end
		pvpplus.engage_player(name)
		minetest.chat_send_all("Player "..name.." engaged himself/herself for the PvP tournament!")
	end
})

minetest.register_chatcommand("tournament_info", {
	params = "",
	description = "Prints tournament informations",
	privs = {},
	func = function(name, param)
		if pvpplus.is_engaging_players() then
			local str = "There is an open tournament which is not yet started (you can engage for this tournament by typing /engage).\n" ..
			            "The tournament was open by: " .. tournament.starting_infos.starter ..
			            "\nThe tournament will start in: " .. os.difftime(tournament.starting_infos.start_time, os.time()) .. " seconds\n" ..
				    "The tournament is open since: " .. os.date("%c", tournament.starting_infos.open_time) ..
				    (tournament.engagement_position and "\nEngaged players will be teleported before the tournament starts.\n" or "\nEngaged players won't be teleported.\n") ..
				    "Currently engaged players are: "
			for player, _ in pairs(tournament.engaged_players) do
				str = str .. player .. ", "
			end
			str = str:sub(0, -3)

			return true, str
		elseif pvpplus.is_running_tournament() then
			local str = "There is a currrently running tournament.\n" ..
			            "The tournament was open by: " .. tournament.starting_infos.starter ..
			            "\nThe tournament is running since: " .. os.date("%c", tournament.starting_infos.start_time) ..
				    "\nInitially engaged players were: "
			for player, _ in pairs(tournament.starting_infos.initially_engaged_players) do
				str = str .. player .. ", "
			end
			str = str:sub(0, -3)

			str = str .. "\nRemaining players are: "
			for player, _ in pairs(tournament.players) do
				str = str .. player .. ", "
			end
			str = str:sub(0, -3)

			return true, str
		else
			return true, "There is no currently running tournament. You can start a new tournament by using /tournament (see /help tournament)."
		end
	end
})

minetest.register_chatcommand("tournament_music_toggle", {
	params = "",
	description = "Toggles the music loop",
	privs = {},
	func = function(name, param)
		if not pvpplus.is_playing_tournament(name) then
			return false, "You are not currently playing a tournament. If you're hearing the tournament music, then it's a bug, please contact a moderator."
		end
		if tournament.sound_handles[name] then
			minetest.sound_stop(tournament.sound_handles[name])
			tournament.sound_handles[name] = nil
			return true, "Stopped music loop."
		else
			tournament.sound_handles[name] = minetest.sound_play("pvpplus_tournament_loop", {
				to_player = name,
				gain = 1.0,
				loop = true,
			})
			return true, "Started music loop."
		end
	end
})

--- /tournament command ---

-- value: {[bool: whether the parameter requires the tournament_mod privilege], [string: type of the wanted value (number or string), nil if no value]}
local param_list = {
	noteleport = {false, nil},
	start_delay = {false, "number"},
	broadcast = {true, nil},
}

local function parse_params(param, name)
	local params = param:split(" ")
	local param_table = {}
	for _, param in ipairs(params) do
		local opt, val = param:match("(.+)=(.*)")
		if opt then
			param = opt
		end

		-- Validity checks...
		if not param_list[param] then
			return false, "Invalid option: " .. param
		end
		if param_list[param][1] and not minetest.get_player_privs(name).tournament_mod then
			return false, "Option " .. param .. " requires the tournament_mod privilege."
		end
		if val and not param_list[param][2] then
			return false, "Option " .. param .. " should not be used with a value."
		end
		if not val and param_list[param][2] then
			return false, "Option " .. param .. " expects a value (e.g. option=value)."
		end
		if param_list[param][2] == "number" and tonumber(val) == nil then
			return false, "Option " .. param .. " expects a number as value."
		end

		if val then
			if param_list[param][2] == "number" then
				param_table[param] = tonumber(val)
			else -- string
				param_table[param] = val
			end
		else
			param_table[param] = true
		end
	end
	return true, param_table
end

minetest.register_chatcommand("tournament", {
	params = "[noteleport] [broadcast] [start_delay=<seconds>]",
	description = "Creates a new tournament, optionally teleporting players to your current position 10 seconds before the tournament starts.",
	privs = {interact = true},
	func = function(name, param)
		local params
		do
			local ok, res = parse_params(param, name)
			if ok == false then
				return false, res
			end
			params = res
		end

		local starting_time = params.start_delay or tournament_starting_time
		if starting_time < 10 or starting_time > 600 then
			return false, "Please set a start delay between 10s and 600s."
		end
		local teleport = params.noteleport ~= true
		tournament.broadcast_messages = params.broadcast or false

		-- Fill start infos
		tournament.starting_infos.starter = name
		tournament.starting_infos.open_time = os.time()
		tournament.starting_infos.start_time = os.time() + starting_time

		-- Allow engaging
		local e, m = pvpplus.allow_engaging(name, teleport)
		if e == false then
			return false, m
		end

		-- Engage starter
		pvpplus.engage_player(name)

		-- Chat messages
		local chat_send = (params.broadcast and minetest.chat_send_all) or pvpplus.chat_send_tournament
		minetest.chat_send_all("The tournament will begin in " .. tostring(starting_time).."s.") -- First chat message is always broadcasted
		minetest.after(starting_time - 10, function()
			pvpplus.chat_send_tournament("The tournament will begin in 10s! Engage yourself by typing /engage!", true)
			pvpplus.teleport_engaged_players()
		end)
		minetest.after(starting_time - 5, function()
			pvpplus.chat_send_tournament("The tournament will begin in 5s!", true)
		end)
		for i = 1, 4 do
			minetest.after(starting_time - i, function()
				pvpplus.chat_send_tournament(tostring(i).."!", true)
			end)
		end

		-- Start tournament
		minetest.after(starting_time, function(name)
			local ok, e = pvpplus.start_tournament()
			if ok == false and e then
				minetest.chat_send_player(name, e)
			end
		end, name)
	end
})
