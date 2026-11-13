extends SceneTree

var failures := 0
const SAVE_PATH := "user://roaming-regression-only.json"

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func tick(frames: int) -> void:
	for i in range(frames): await process_frame

func run() -> void:
	root.size = Vector2i(960,540)
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = ArcadeProfile.new()
	game.profile.save_path = SAVE_PATH
	game.profile.unlocked = 4
	game.use_fixed_seed = true
	game.guards_enabled = false
	root.add_child(game)
	await tick(3)
	for scenario in [{"level":1,"seed":7},{"level":4,"seed":17}]:
		game.fixed_seed = scenario.seed
		game.begin_round(scenario.level)
		await tick(4)
		var starts := {}
		var visits: Array[Dictionary] = []
		for hen in game.hens:
			starts[game.world.patrol_sector(hen.position)] = true
			visits.append({game.world.patrol_sector(hen.position):true})
		expect(starts.size() == 4,"Initial hens must cover all four map quadrants")
		for frame in range(2400):
			await process_frame
			for i in range(visits.size()):
				visits[i][game.world.patrol_sector(game.hens[i].position)] = true
		for i in range(visits.size()):
			expect(visits[i].size() >= 3,"Hen %d on stage %d must actually traverse at least three quadrants in 40 seconds (visited %s)" % [i,scenario.level,visits[i].keys()])
			var hen: ArcadeHen = game.hens[i]
			hen.set_physics_process(false)
			hen._sectors.clear()
			var destinations := {}
			for choice in range(4):
				hen._choose_roam_target()
				expect(hen.roam_target != Vector2.INF,"Roaming must select a reachable destination")
				destinations[game.world.patrol_sector(hen.roam_target)] = true
				expect(CoopNavigation.next_offset(hen,hen.roam_target,true) != Vector2.INF,"A global target must have a valid route around cover")
			expect(destinations.size() == 4,"Every shuffled patrol tour must sample the whole map")
		print("Stage ",scenario.level," actual quadrant visits: ",visits)
		game.abandon_round()
	game.begin_round(1)
	await tick(3)
	for hen in game.hens: hen.set_physics_process(false)
	for egg in game.eggs: egg.queue_free()
	game.eggs.clear()
	var origin := game.world.free_point(20,true)
	for attempt in range(300):
		if origin.x > 200 and origin.x < 650 and origin.y > 220 and game.world.step_clear(origin,origin+Vector2(110,0)): break
		origin = game.world.free_point(20,true)
	game.player.position = origin
	var inside := origin+Vector2(30,0)
	game._spawn_egg_at(inside,false)
	var egg: ArcadeEgg = game.eggs.back()
	expect(egg.scale.x >= 1.2,"Ground eggs should be visibly larger")
	var pointer := inside+Vector2(0,21/game.camera.zoom.x)
	game._update_pickup_feedback(pointer)
	expect(egg.highlighted,"Click assistance and hover must agree outside the small egg sprite")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.get_canvas_transform()*pointer
	Input.parse_input_event(click)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	expect(game.collected == 1,"Clicking 21 screen pixels beside an egg must collect it")
	game._spawn_egg_at(origin+Vector2(66,0),false)
	game._spawn_egg_at(origin+Vector2(85,0),false)
	var outside: ArcadeEgg = game.eggs.back()
	expect(game.collect_at(outside.position),"Assistance should prefer a nearby reachable egg over the closest distant one")
	expect(game.eggs.has(outside) and not outside.claimed,"Click assistance must never collect the egg outside player reach")
	game.chain = 0
	game._update_hud()
	for i in range(5): game._award(origin,false)
	expect(game.ui.combo_label.text.contains("5") and game.ui._combo_pop_age == 0,"Five pickups must trigger a local combo pop")
	expect(game.ui.combo_anchor.position.distance_to(game.get_canvas_transform()*game.player.position) < 150 and game.ui.combo_anchor.position.y > 75,"Combo feedback must be near the player, not at the top of the screen")
	var combo_position := game.ui.combo_anchor.position
	game.player.position += Vector2(40,0)
	game._update_hud()
	expect(game.ui.combo_anchor.position.x > combo_position.x+30,"Combo feedback must follow the player")
	# Protection also prevents a capture if a farmer is already next to the player.
	game._spawn_farmer()
	game.farmer.position = game.player.position
	await tick(4)
	expect(game.running and not game.farmer.sees_player,"Opening protection must prevent farmer capture too")
	game.protection_left = 0
	game.player.invulnerable = false
	await tick(4)
	expect(not game.running and game.last_result.get("caught",false),"Capture must resume after opening protection ends")
	game.queue_free()
	await tick(2)
	DirAccess.remove_absolute(SAVE_PATH)
	if failures == 0: print("PASS: whole-map navigation and coverage, generous click targeting, strict reach, player-local combo bursts and spawn capture immunity")
	quit(1 if failures else 0)
