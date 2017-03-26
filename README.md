# PvP Plus

This mod adds many PvP features that allow players to enable / disable their own PvP and to do PvP tournaments.
Some code and images are from the PvP-Button Mod by Phiwari123.

## Usage

PvP can be enabled/disabled from the inventory.

A new tournament can be initiated by a player by typing /tournament.
Then, each playing wanting to play in the tournament has to type /engage during the next minute (this delay is customizable using the `pvpplus.tournament_starting_time` setting, specified in seconds).
Any engaged player can leave the current tournament by using `/leave_tournament`.

Some additional commands are only executable by the players possessing the `tournament_mod` privilege:
* `/start_global_tournament`: immediately starts a tournament engaging every connected players (except those who don't have the interact privilege)
* `/stop_tournament`: stops the current tournament
* `/remove_from_tournament <name>`: removes a player from the current tournament
* `/add_to_tournament <name>`: adds a player to the current tournament

## Settings

* `pvpplus.enable_sound_loop = true`: whether to play a looped epic music during the tournament

## API

```lua
-- Enabling/disabling PvP:
pvpplus.pvp_set(player_name, state)
pvpplus.pvp_enable(player_name)
pvpplus.pvp_disable(player_name)
pvpplus.pvp_toggle(player_name)
pvpplus.is_pvp(player_name)

-- PvP tournaments:
pvpplus.engage_player(player_name) -- Engage a player for the next tournament
pvpplus.is_engaged(player_name) -- Is this player engaged for the next tournament ?
pvpplus.is_engaging_players() -- Is there an open tournament ?
pvpplus.start_tournament(starter_name) -- Start a tournament (at least 2 players have to be engaged)
pvpplus.start_global_tournament(starter_name) -- Start a tournament engaging every connected players
pvpplus.stop_tournament() -- Stop the current tournament
pvpplus.allow_engaging(starter_name, teleport) -- Allow players to engage themselves by typing /engage. Teleport is a Boolean
pvpplus.teleport_engaged_players() -- Teleport engaged players to the tournament position (only works if allow_engaging was called with teleport = true). Players who engage after this function has been run and before the tournament starts will be immediately teleported.
pvpplus.remove_from_tournament(player_name) -- Remove a player from the current tournament
pvpplus.add_to_tournament(player_name) -- Add a player to the current tournament
pvpplus.is_playing_tournament(player_name) -- Is this player playing in the current tournament ?
pvpplus.is_running_tournament() -- Is there a tournament currently running ?
```

## TODO

* Add a privilege for changing PvP state
* Add a HUD for the tournament score
* Make the dependence to unified_inventory optional by adding chat commands to change PvP state
* Add a formspec for managing tournaments, accessible from the inventory
* Testing

## Sounds credits

* pvpplus_tournament_start: https://freesound.org/people/anderz000/sounds/204310/
* pvpplus_tournament_end: https://freesound.org/people/kendog88/sounds/215748/
* pvpplus_tournament_loop: http://freesound.org/people/joshuaempyre/sounds/250856/
