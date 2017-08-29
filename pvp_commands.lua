local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	S = function(translated)
		return translated
	end
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
	params = "[<player>]",
	description = S("Enables PvP"),
	privs = {
		pvp = true
	},
	func = function(name, param)
		if param ~= "" then
			if not minetest.check_player_privs(name, "pvp_admin") then
				return false, S("You cannot change other players PvP state unless you have the pvp_admin privilege.")
			end
			name = param
		end
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
		if param ~= "" then
			if not minetest.check_player_privs(name, "pvp_admin") then
				return false, S("You cannot change other players PvP state unless you have the pvp_admin privilege.")
			end
			name = param
		end
		if not pvpplus.is_pvp(name) then
			return false, S("Your PvP is already disabled.")
		end
		return pvpplus.pvp_disable(name)
	end
})
