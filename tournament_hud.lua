local tournament = pvpplus.tournament -- Shortcut table
tournament.hud = {}
tournament.hud_list = {}

-- These values cannot be exact for all clients. Default values should be fine for most of them.
local margin = tonumber(minetest.settings:get("pvpplus.tournament_hud_margin")) or 10 -- pixels
local font_width = tonumber(minetest.settings:get("pvpplus.font_width")) or 5 -- pixels
local separation = tonumber(minetest.settings:get("pvpplus.tournament_hud_separation")) or 18 -- pixels

function pvpplus.tournament_hud_update_list()
	tournament.hud_list = {}

	for name, _ in pairs(tournament.sent_damages) do
		if pvpplus.get_score(name) then
			table.insert(tournament.hud_list, {
				name = name,
				score = pvpplus.get_score(name),
				status = pvpplus.is_playing_tournament(name)
			})
		end
	end

	table.sort(tournament.hud_list, function(a, b) return a.score > b.score end)
end

local function format_element(i, element, len)
	if not len then
		return tostring(i) .. " " .. element.name .. " " .. tostring(element.score)
	else
		local str = tostring(i) .. " " .. element.name .. " "
		local score = tostring(element.score)
		local score_len = #score
		while #str + score_len < len do
			str = str .. " "
		end
		str = str .. score
		return str
	end
end

function pvpplus.tournament_hud_update(player, update_list)
	if update_list ~= false then
		pvpplus.tournament_hud_update_list()
	end

	local name = player:get_player_name()
	if not tournament.hud[name] then
		tournament.hud[name] = {}
	end

	-- Compute x offset
	local max_length = 0
	for i, element in ipairs(tournament.hud_list) do
		local len = string.len(format_element(i, element))
		if len > max_length then
			max_length = len
		end
	end
	if max_length == 0 then
		return
	end
	local x_offset = -(max_length * font_width + margin)

	-- Remove the old HUD
	pvpplus.tournament_hud_clear(player)
	-- Add the new HUD
	for i, element in ipairs(tournament.hud_list) do
		tournament.hud[name][i] = player:hud_add({
			name = "Tournament HUD section " .. tostring(i),
			hud_elem_type = "text",
			aligment = {x = 1, y = 0},
			position = {x = 1, y = 0.2},
			-- Colors: self is red, playing players are green, no-longer playing players are blue.
			number = (element.name == name and 0xFF0000) or ((element.status and 0x00FF00) or 0x0000FF),
			text = format_element(i, element, max_length),
			offset = {x = x_offset, y = (i-1)*separation}
		})
	end
end

function pvpplus.tournament_hud_update_all()
	pvpplus.tournament_hud_update_list()
	for name, _ in pairs(tournament.sent_damages) do
		local player = minetest.get_player_by_name(name)
		if player then
			pvpplus.tournament_hud_update(player, false)
		end
	end
end

function pvpplus.tournament_hud_clear(player)
	local name = player:get_player_name()
	if not tournament.hud[name] then -- Happens on first update
		return
	end

	for _, id in ipairs(tournament.hud[name]) do
		player:hud_remove(id)
	end
end
