extends SceneTree

var failures := 0
const SAVE := "user://map-progress-regression.json"

func _initialize() -> void: call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func tick(frames: int) -> void:
	for i in range(frames): await process_frame

func run() -> void:
	root.size = Vector2i(960,540)
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.free_stage_select = false
	game.profile = ArcadeProfile.new()
	game.profile.powerup_tutorials = [true,true,true]
	game.profile.save_path = SAVE
	game.guards_enabled = false
	game.use_fixed_seed = true
	root.add_child(game)
	await tick(3)
	game.begin_round(1,4)
	expect(not game.running and game.profile.active_map == 1,"Locked maps must not start or reset the active map")
	for map_index in range(1,5):
		if map_index > 1:
			var wallet := game.profile.coins
			expect(game.profile.unlocked_maps >= map_index,"Clearing a fourth room must unlock the next map")
			game._select_map(map_index)
			game._buy_upgrade(0)
			expect(not game.running and game.profile.active_map == map_index,"The menu must sell new-map buffs before starting, without an extra start screen")
			expect(game.profile.coins == wallet-20 and game.profile.upgrades == [1,0,0],"Entry-shop purchase must preserve the wallet minus its price and reset old-map buffs")
			game._request_round(1,map_index)
			expect(game.transitioning and not game.running,"Map entry must run a non-gameplay transition")
			await tick(70)
			expect(game.running and not game.ui.overlay.visible,"One start click must enter the next map after its transition")

		for room in range(1,5):
			var buffs := game.profile.upgrades.duplicate()
			game.begin_round(room,map_index)
			await tick(3)
			expect(game.running and game.current_map == map_index and game.current_level == room,"All sixteen map-room combinations must play")
			expect(game.profile.upgrades == buffs,"Buffs must persist between rooms of the same map")
			expect(game.eggs[0].theme_index == map_index-1 and game.nests[0].theme_index == map_index-1,"Ground and nest resources must use the selected map skin")
			expect(game.hens.size() == ArcadeDifficulty.for_stage(map_index,room).animals,"Patrol population must match the map/room difficulty")
			if map_index > 1:
				expect(game.hens[0].get_node("Body").get("theme_index") == map_index-1,"Sheep, squirrels and dogs must replace chicken art")
			var before := game.profile.coins
			game.score = 125
			game.collected = 50
			game.time_left = 0.001
			game._process(0.01)
			expect(not game.running and game.profile.coins == before+25,"Every room must award its coins once")
			game.finish_round()
			expect(game.profile.coins == before+25,"Repeated settlement must not mint coins twice")
			if room < 4:
				expect(game.profile.unlocked == room+1 and game.profile.unlocked_maps == map_index,"Small-room wins must not unlock the next map early")
				var index := room-1
				if game.profile.coins >= game.profile.cost(index): expect(game.profile.buy(index),"The inter-room shop must sell buffs")
			else:
				expect(game.profile.map_complete and game.profile.cleared[map_index-1],"A fourth-room win must mark its map complete")
				expect(game.profile.map_best[map_index-1] == 500,"Map totals must include exactly its four rooms")
			if map_index == 2 and room == 2:
				var reload := ArcadeProfile.new()
				reload.save_path = SAVE
				reload.load_progress()
				expect(reload.coins == game.profile.coins and reload.upgrades == game.profile.upgrades and reload.active_map == 2 and reload.unlocked == 3,"Closing and reopening must preserve wallet, current map, buffs and next room")
				game.profile = reload
	expect(game.profile.cleared == [true,true,true,true] and game.profile.unlocked_maps == 4,"The complete path must unlock and clear all four maps")
	var wallet := game.profile.coins
	game._restart_map(4)
	expect(game.profile.coins == wallet and game.profile.upgrades == [0,0,0] and game.profile.unlocked == 1,"Restarting a map must keep coins while resetting that run")
	game.queue_free()
	await tick(2)
	var file := FileAccess.open(SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"coins":73,"unlocked":3,"upgrades":[1,2,0],"best":[12,25,0,0]}))
	file.close()
	var migrated := ArcadeProfile.new()
	migrated.save_path = SAVE
	migrated.load_progress()
	expect(migrated.coins == 73 and migrated.upgrades == [1,2,0] and migrated.unlocked == 3 and migrated.best[1] == 25,"Old saves must migrate without losing coins, buffs or room progress")
	expect(not migrated.start_map(4) and migrated.coins == 73,"Invalid map entry must not mutate migrated progress")
	migrated.unlocked_maps = 2
	expect(migrated.start_map(2) and migrated.coins == 73 and migrated.upgrades == [0,0,0],"Migrated coins must survive the next map too")
	DirAccess.remove_absolute(SAVE)
	if failures == 0: print("PASS: 16 playable rooms, sequential map unlocks, permanent coins, map-local buffs, entry shop, transitions, reskins, restart and old-save migration")
	quit(1 if failures else 0)
