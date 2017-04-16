if not minetest.setting_getbool("enable_pvp") then
	minetest.log("error", "[PvP Plus] PvP Plus cannot work if PvP is disabled. Please enable PvP.")
else
	dofile(minetest.get_modpath(minetest.get_current_modname()).."/pvp.lua")
end
