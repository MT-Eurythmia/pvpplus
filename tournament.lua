local tournament_starting_time = tonumber(minetest.setting_get("pvpplus.tournament_starting_time")) or 60 -- seconds

local previous_player_transfer_distance

local tournament = {
	engaging_players = false,
	running_tournament = false,
	engaged_players = {},
	players = {},
	sent_damages = {},
	received_damages = {},
	kills = {}
}

function pvpplus.engage_player(player_name)
	tournament.engaged_players[player_name] = true
	minetest.chat_send_player(player_name, "You have been engaged for a PvP tournament!")
end

function pvpplus.start_tournament(starter_name)
	if tournament.running_tournament then
		minetest.chat_send_player(starter_name, "There is already a running tournament.")
		return false
	end

	-- Stop engaging
	tournament.engaging_players = false

	local count = 0
	for _, _ in pairs(tournament.engaged_players) do
		count = count + 1
	end
	if count <= 1 then
		minetest.chat_send_player(starter_name, "There are not enough engaged players to start a tournament.")
		return false
	end

	for player, _ in pairs(tournament.engaged_players) do
		 -- Enable PvPs
		pvpplus.pvp_enable(player)
		-- Move the the playing table
		tournament.players[player] = true
		tournament.sent_damages[player] = 0
		tournament.received_damages[player] = 0
		tournament.kills[player] = 0
	end
	tournament.engaged_players = {}

	-- Set the player transfer distance
	previous_player_transfer_distance = minetest.setting_get("player_transfer_distance")
	minetest.setting_set("player_transfer_distance", 0) -- 0 = unlimited

	-- Send the final chat message!
	minetest.chat_send_all("PVP TOURNAMENT BEGINS! Started by " .. starter_name)

	-- Set the tournament flag
	tournament.running_tournament = true
end

function pvpplus.start_global_tournament(starter_name)
	local players = minetest.get_connected_players()

	-- Engage all connected players
	for _, player in ipairs(players) do
		local player_name = player:get_player_name()
		if minetest.get_player_privs(player_name).interact then -- Well, don't engage players who don't have interact.
			pvpplus.engage_player(player:get_player_name())
		end
	end

	-- Start the tournament
	pvpplus.start_tournament(starter_name)
end

function pvpplus.stop_tournament()
	if not pvpplus.is_running_tournament() then
		return false
	end

	minetest.chat_send_all("END OF TOURNAMENT!")

	-- Calculate rating
	local rating = {}
	for name, _ in pairs(tournament.sent_damages) do
		table.insert(rating, {
			name = name,
			score = tournament.sent_damages[name] - tournament.received_damages[name] + tournament.kills[name] * 20
		})
	end
	table.sort(rating, function(a, b) return a.score < b.score end)

	-- Print it
	minetest.chat_send_all("***************************** TOURNAMENT RATING *****************************")
	minetest.chat_send_all("+--------------+-------+--------+---------------+-------------------+-------+")
	minetest.chat_send_all("| player       | rank  | score  | sent damages  | received damages  | kills |")
	minetest.chat_send_all("+--------------+-------+--------+---------------+-------------------+-------+")
	for i, v in ipairs(rating) do
		local player = v.name
		local rank = tostring(i)
		local score = tostring(v.score)
		local sent_damages = tostring(tournament.sent_damages[v.name])
		local received_damages = tostring(tournament.received_damages[v.name])
		local kills = tostring(tournament.kills[v.name])

		local str = "| "

		local function cat_str(value, len)
			str = str .. value
			for n = #str, len do
				str = str .. " "
			end
			str = str .. "| "
		end

		cat_str(player, 15)
		cat_str(rank, 23)
		cat_str(score, 32)
		cat_str(sent_damages, 48)
		cat_str(received_damages, 68)
		cat_str(kills, 73)

		minetest.chat_send_all(str)
	end
	minetest.chat_send_all("+--------------+-------+--------+---------------+-------------------+-------+")

	-- Clean tables
	tournament = {
		engaging_players = false,
		running_tournament = false,
		engaged_players = {},
		players = {},
		sent_damages = {},
		received_damages = {},
		kills = {}
	}

	-- Change the player transfer distance back
	minetest.setting_set("player_transfer_distance", previous_player_transfer_distance)
end

function pvpplus.allow_engaging(starter_name)
	tournament.engaging_players = true
	minetest.chat_send_all(starter_name .. " opened a tournament! Type /engage to engage yourself in the tournament!")
end

function pvpplus.remove_from_tournament(player_name)
	-- Remove from players table
	tournament.players[player_name] = nil

	-- Send a chat message
	if minetest.get_player_by_name(player_name) then
		minetest.chat_send_player(player_name, "You are no longer playing the tournament.")
	end
	minetest.chat_send_all("Player "..player_name.." is no longer playing the tournament.")

	-- Check if the tournament is ended
	local count = 0
	for _, _ in pairs(tournament.players) do count = count + 1 end

	if count <= 1 then -- 1 or less remaining players
		pvpplus.stop_tournament()
	end
end

function pvpplus.add_to_tournament(player_name)
	if not pvpplus.is_running_tournament() or pvpplus.is_playing_tournament(player_name) then
		return false
	end

	-- Add to tables
	tournament.players[player_name] = true
	tournament.sent_damages[player_name] = 0
	tournament.received_damages[player_name] = 0
	tournament.kills[player_name] = 0

	-- Send a chat message
	if minetest.get_player_by_name(player_name) then
		minetest.chat_send_player(player_name, "You joined the current tournament!")
	end
	minetest.chat_send_all("Player "..player_name.." joined the current tournament!")
end

function pvpplus.is_playing_tournament(player_name)
	if tournament.players[player_name] then
		return true
	else
		return false
	end
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
		-- Removing the player from the tournament is done by the on_dieplayer callback.
	end
end

minetest.register_privilege("tournament_mod", "PvP Tournament Moderator")

minetest.register_chatcommand("start_global_tournament", {
	params = "",
	description = "Start a PvP tournament engaging every connected players and starting immediately",
	privs = {interact = true, tournament_mod = true},
	func = function(name, param)
		pvpplus.start_global_tournament(name)
		return true
	end
})

minetest.register_chatcommand("stop_tournament", {
	params = "",
	description = "Stops the current PvP tournament",
	privs = {interact = true, tournament_mod = true},
	func = function(name, param)
		pvpplus.stop_tournament()
		return true
	end
})

minetest.register_chatcommand("remove_from_tournament", {
	params = "<name>",
	description = "Removes a player from a PvP tournament",
	privs = {interact = true, tournament_mod = true},
	func = function(name, param)
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
	privs = {interact = true, tournament_mod = true},
	func = function(name, param)
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

minetest.register_chatcommand("tournament", {
	params = "",
	description = "Creates a new tournament",
	privs = {interact = true},
	func = function(name, param)
		if pvpplus.is_running_tournament() then
			return false, "There is already a running tournament."
		end

		-- Allow engaging
		pvpplus.allow_engaging(name)

		-- Chat messages
		minetest.chat_send_all("The tournament will begin in " .. tostring(tournament_starting_time).."s.")
		minetest.after(tournament_starting_time - 10, function()
			minetest.chat_send_all("The tournament will begin in 10s! Engage yourself by typing /engage!")
		end)
		minetest.after(tournament_starting_time - 5, function()
			minetest.chat_send_all("The tournament will begin in 5s!")
		end)
		for i = 1, 4 do
			minetest.after(tournament_starting_time - i, function()
				minetest.chat_send_all(tostring(i).."!")
			end)
		end

		-- Start tournament
		minetest.after(tournament_starting_time, function(name)
			pvpplus.start_tournament(name)
		end, name)
	end
})

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	if pvpplus.is_playing_tournament(player_name) then
		pvpplus.remove_from_tournament(player_name)
	end
end)

minetest.register_on_dieplayer(function(player)
	local player_name = player:get_player_name()
	if pvpplus.is_playing_tournament(player_name) then
		pvpplus.remove_from_tournament(player_name)
	end
end)
