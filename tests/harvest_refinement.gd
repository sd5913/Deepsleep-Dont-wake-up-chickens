extends SceneTree
var failures := 0
const SAVE := "user://harvest-refinement-only.json"
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func tick(frames: int) -> void:
	for i in range(frames): await physics_frame
func freeze_guards(game: ArcadeGame) -> void:
	for hen in game.hens:
		hen.set_physics_process(false)
		hen.sees_player = false
func run() -> void:
	root.size = Vector2i(960,540)
	for map_index in range(1,5):
		for room in range(2,5):
			var now := ArcadeDifficulty.for_stage(map_index,room)
			var before := ArcadeDifficulty.for_stage(map_index,room-1)
			expect(now.pressure > before.pressure and now.farmer_chase > before.farmer_chase and now.summon_at == 100.0 and before.summon_at == 100.0,"Every chapter must get harder room by room")
		if map_index > 1:
			var start := ArcadeDifficulty.for_stage(map_index,1)
			expect(start.pressure > ArcadeDifficulty.for_stage(map_index-1,1).pressure and start.pressure < ArcadeDifficulty.for_stage(map_index-1,4).pressure,"A new chapter must start above the previous start but below its finale")
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = ArcadeProfile.new()
	game.profile.powerup_tutorials = [true,true,true]
	game.profile.save_path = SAVE
	game.use_fixed_seed = true
	game.guards_enabled = false
	root.add_child(game)
	await tick(4)
	game.set_process(false)
	game.begin_round(2,1)
	await tick(3)
	freeze_guards(game)
	game.player.position = game.world.free_point(30,true)
	game._release_snake(game.player.position-Vector2(40,0))
	var snake: ArcadeSnake = game.snakes.back()
	var ground := snake.position
	await tick(16)
	expect(snake.frame_index == 0 and snake.art.position.length() > 0 and snake.art.scale.x > 0.6,"The first phase must lift and enlarge a whole egg toward the player's hand")
	var held_x := snake.art.position.x
	game.player.position.x += 12
	await tick(1)
	expect(snake.art.position.x > held_x+5,"The lifted egg must follow the hand while the player moves")
	game.player.position.x -= 12
	await tick(1)
	await tick(17)
	expect(snake.frame_index == 1 and snake.position == ground,"Cracked egg must stay visible before the snake starts moving")
	await tick(17)
	expect(snake.did_hatch and snake.position == ground and game.ui.reaction_label.text.contains("小蛇") and game.player._startle_left > 0.0,"Hatching must show the frightened player and a large local warning before motion")
	expect(not game.player.movement_locked,"The hatch animation must never lock player movement")
	await tick(25)
	expect(snake.position == ground and snake.age < ArcadeSnake.BURST_SECONDS,"Reaction window must remain open for over one second after collection")
	await tick(19)
	expect(snake.position != ground and ArcadeSnake.DASH_SPEED == 460.0,"After 1.5 seconds the snake must dash at its original speed")
	game.abandon_round()
	for map_index in range(1,5):
		game.begin_round(1,map_index)
		await tick(3)
		expect(game.world.theme_index == map_index,"The world must receive the selected map theme")
		if map_index == 1: expect(game.world.cover_props.all(func(p): return p == -1),"Chicken coop must keep its original crates")
		if map_index == 2: expect(game.world.cover_props.has(2),"Sheep pen must include hay cover")
		if map_index == 3: expect(game.world.cover_props.has(1) and game.world.cover_props.has(5),"Squirrel map must include pine and bush cover")
		if map_index == 4: expect(game.nests[0].has_node("VegetableBasket") and game.world.cover_props.has(3),"Garden must use vegetable baskets and fence/hedge cover")
		game.abandon_round()
	game.begin_round(4,3)
	await tick(3)
	freeze_guards(game)
	game._process(46.0)
	game._spawn_batch(600)
	expect(game.hens.all(func(hen): return not hen.golden) and game.golden_count == 0,"Squirrel rooms must never introduce golden squirrels")
	expect(game.eggs.any(func(egg): return egg.golden) and game.eggs.any(func(egg): return not egg.golden),"Golden pinecones must be part of random ground batches alongside ordinary cones")
	game.abandon_round()
	game.guards_enabled = true
	var summon_times: Array[float] = []
	for scenario in [[1,1],[4,4]]:
		game.begin_round(scenario[1],scenario[0])
		await tick(3)
		freeze_guards(game)
		game.protection_left = 0
		game.player.invulnerable = false
		game.hens[0].sees_player = true
		game.hens[0]._alarm_pending = true
		game._update_guards(0.01)
		expect(game._shake_left > 0 and game.ui.reaction_label.text.contains("被发现"),"Detection in any chapter must start shake plus a visible local warning")
		game._update_shake(0.016)
		expect(game.camera.offset.length() > 0,"Shake must actually move the camera")
		game._reset_shake()
		game._update_guards(0.05)
		expect(game._shake_left == 0,"Sustained sight must not restart shake every frame")
		var elapsed := 0.06
		while not is_instance_valid(game.farmer) and elapsed < 15.0:
			game._update_guards(0.05)
			elapsed += 0.05
		expect(is_instance_valid(game.farmer),"Sustained exposure must bring in a real farmer")
		summon_times.append(elapsed)
		if scenario[0] == 1:
			expect(game.farmer.chase_speed < game.player.move_speed,"Opening chapter should allow running away on clear ground")
			game.abandon_round()
	expect(summon_times[1] < summon_times[0] and game.farmer.chase_speed < game.player.move_speed*0.7,"Later chapters may summon sooner under exposure, but the farmer must remain distinctly slower than the player")
	var origin := game.world.free_point(25,true)
	for attempt in range(500):
		if game.world.step_clear(origin,origin+Vector2(110,0)): break
		origin = game.world.free_point(25,true)
	game.player.position = origin+Vector2(90,0)
	game.player.set_physics_process(false)
	game.farmer.position = origin
	await tick(40)
	expect(not game.running and game.last_result.get("caught",false),"Standing in the final farmer's clear pursuit path must actually end the round in capture")
	expect(game.camera.offset == Vector2.ZERO,"Finishing must clear camera shake")
	game.queue_free()
	await tick(2)
	DirAccess.remove_absolute(SAVE)
	if failures == 0: print("PASS: readable 1.5s lifted/cracked egg and fright, unchanged dash speed, themed covers/baskets, random gold cones without gold squirrels, chapter difficulty curve, detection shake and actual farmer capture; summon seconds ",summon_times)
	quit(1 if failures else 0)
