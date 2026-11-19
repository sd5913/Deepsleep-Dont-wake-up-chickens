extends SceneTree
var failures := 0
const SAVE := "user://collection-escape-regression.json"
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func tick(frames: int) -> void:
	for i in range(frames): await physics_frame
func clear_eggs(game: ArcadeGame) -> void:
	for egg in game.eggs: egg.queue_free()
	game.eggs.clear()
func freeze_guards(game: ArcadeGame) -> void:
	for hen in game.hens:
		hen.set_physics_process(false)
		hen.sees_player = false
		hen.take_alarm()
func run() -> void:
	root.size = Vector2i(960,540)
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = ArcadeProfile.new()
	game.profile.save_path = SAVE
	game.profile.coins = 100
	# This regression exercises escape rather than first-encounter modal teaching.
	game.profile.powerup_tutorials = [true,true,true]
	game.use_fixed_seed = true
	game.guards_enabled = false
	root.add_child(game)
	await tick(3)
	game.begin_round(1,1)
	await tick(3)
	game.set_process(false)
	freeze_guards(game)
	clear_eggs(game)
	var origin := game.world.free_point(30,true)
	for attempt in range(1000):
		if game.world.step_clear(origin,origin+Vector2(65,0)) and game.world.step_clear(origin,origin-Vector2(65,0)) and game.world.step_clear(origin,origin+Vector2(0,80)): break
		origin = game.world.free_point(30,true)
	game.player.position = origin
	for offset in [Vector2(60,0),Vector2(-60,0),Vector2(0,65),Vector2(0,80)]: game._spawn_egg_at(origin+offset,offset == Vector2(0,65))
	expect(game.eggs.size() == 4 and game.profile.upgrades == [0,0,0],"Fixture must include four eggs and no purchased gather upgrade")
	var outside: ArcadeEgg = game.eggs.back()
	game._update_pickup_feedback(origin+Vector2(60,0))
	expect(game.eggs[0].highlighted and game.eggs[1].highlighted and not outside.highlighted,"Hovering one reachable egg must highlight the whole eligible ring")
	expect(game.collect_at(origin+Vector2(60,0)) and game.collected == 3 and game.score == 7,"One click must collect normal and gold eggs across the entire player ring, including the opposite side")
	expect(game.eggs.size() == 1 and game.eggs[0] == outside and not outside.claimed,"An egg outside the ring must remain untouched")
	expect(not game.collect_at(origin+Vector2(60,0)) and game.collected == 3,"Clicking an empty spot must not automatically sweep nearby eggs")
	clear_eggs(game)
	var cover: Rect2 = game.world.solids[0]
	game.player.position = cover.position+Vector2(-24,24)
	var blocked := cover.position+Vector2(24,-24)
	var visible := game.player.position-Vector2(5,0)
	game._spawn_egg_at(blocked,false)
	game._spawn_egg_at(visible,false)
	expect(game.eggs.size() == 2 and game.player.position.distance_to(blocked) < game.pickup_radius() and not game.can_collect_point(blocked),"Blocked egg must lie inside the ring but across cover")
	game.collect_at(visible)
	expect(game.eggs.size() == 1 and game.eggs[0].position == blocked,"Whole-ring collection must preserve cover occlusion")
	game.abandon_round()
	game.profile.upgrades = [2,2,2]
	game._select_map(2)
	game._select_level(3)
	game._request_round(3,2)
	game._request_round(3,2)
	await tick(70)
	expect(game.running and game.current_map == 2 and game.current_level == 3 and not game.ui.overlay.visible,"A new-map start must launch the selected room once after a single transition")
	expect(game.profile.coins == 100 and game.profile.upgrades == [0,0,0],"Direct start must preserve coins and reset only old-map buffs")
	game.abandon_round()
	game._select_map(3)
	game._buy_upgrade(0)
	expect(not game.running and game.profile.active_map == 3 and game.profile.coins == 80 and game.profile.upgrades == [1,0,0],"Preview menu must allow buying a new-map buff without consuming an extra start click")
	game._request_round(1,3)
	await tick(70)
	expect(game.running and game.profile.upgrades == [1,0,0],"One start after shopping must retain the purchased new-map buff")
	game.abandon_round()
	game.profile.map_complete = true
	game._request_round(1,3)
	await tick(70)
	expect(game.running and not game.ui.overlay.visible and game.profile.coins == 80 and game.profile.upgrades == [0,0,0],"Replaying a completed map must start with one click too")
	game.abandon_round()
	for map_index in range(1,5):
		for room in range(1,5):
			var settings := ArcadeDifficulty.for_stage(map_index,room)
			expect(settings.summon_at == 100.0 and settings.farmer_chase < 231.0,"All sixteen rooms must require alert 100 and a farmer substantially slower than the player")
	game.begin_round(4,4)
	await tick(3)
	freeze_guards(game)
	game.guards_enabled = true
	game.protection_left = 0
	game.player.invulnerable = false
	game.alert._calm_delay_left = 100
	game.alert.level = 99
	game._update_guards(0.2)
	expect(not is_instance_valid(game.farmer) and game._farmer_warning == 0.0,"Alert 99 must never summon the farmer")
	game.alert.level = 100
	game._update_guards(0.01)
	expect(game._farmer_warning > 0,"Alert 100 must begin the entrance warning")
	game._update_guards(2.0)
	expect(is_instance_valid(game.farmer) and game.farmer.chase_speed < game.player.move_speed*0.7,"Spawned final-room farmer must remain slower than the player")
	var remembered := game.farmer.last_known_position
	game.player.position += Vector2(30,0)
	game.hens[0].sees_player = true
	game._update_guards(0.01)
	expect(game.farmer.last_known_position == remembered,"Other animals must not continuously give the farmer an invisible live target")
	game.hens[0].sees_player = false
	game.farmer.position = game.world.bounds.position+Vector2(32,32)
	game.player.position = game.world.bounds.end-Vector2(32,32)
	game.farmer.unseen_seconds = 0
	await tick(170)
	expect(is_instance_valid(game.farmer) and not game.farmer.leaving,"The farmer should search briefly before forgetting")
	var unseen := game.farmer.unseen_seconds
	game.toggle_pause()
	await tick(20)
	expect(is_equal_approx(game.farmer.unseen_seconds,unseen),"Pausing must freeze the sight-loss timer")
	game.toggle_pause()
	await tick(20)
	expect(game.farmer.leaving and game.alert.level <= 40 and game._farmer_cooldown_left > 0,"Three continuous seconds unseen must end pursuit, lower alert and start a safe interval")
	game.player.position = game.farmer.position
	await tick(4)
	expect(game.running and not game.farmer.sees_player,"A farmer giving up must not reacquire or catch a player walking past")
	for i in range(550):
		if not is_instance_valid(game.farmer): break
		await physics_frame
	expect(not is_instance_valid(game.farmer),"A forgotten chase must leave the map within a bounded time")
	game.alert.level = 100
	game._update_guards(0.1)
	expect(not is_instance_valid(game.farmer) and game._farmer_warning == 0.0,"A new farmer must not immediately replace the departing one")
	game.queue_free()
	await tick(2)
	DirAccess.remove_absolute(SAVE)
	if failures == 0: print("PASS: whole-ring pickup without upgrades, gold/normal reach and cover, one-click new/replay starts, pre-start shop, alert 100, slower farmer, no live reports, 3-second forget, pause and departure grace")
	quit(1 if failures else 0)
