local MAX_TIME_MOTIONLESS = 7 -- seconds
local HP_PER_HIT = 2

minetest.register_globalstep(function(dtime)
	if not pvpplus.is_running_tournament() or not pvpplus.tournament.damage_motionless then
		return
	end

	for _, player in ipairs(pvpplus.get_tournament_players()) do
		local pos = vector.round(player:get_pos())
		local table_entry = pvpplus.tournament.motion_table[player:get_player_name()]
		print(dump(table_entry))
		if vector.equals(pos, table_entry.pos) then
			if os.difftime(os.time(), table_entry.time) > MAX_TIME_MOTIONLESS then
				minetest.chat_send_player(player:get_player_name(), "Move!")
				player:set_hp(player:get_hp() - HP_PER_HIT)
				table_entry.time = table_entry.time + 1 -- hit each second
			end
		else
			table_entry.pos = pos
			table_entry.time = os.time()
		end
	end
end)
