extends SceneTree

var failures := 0
const SAVE := "user://snake-playtest-regression.json"
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func tick(frames: int) -> void:
	for i in range(frames): await physics_frame
func hidden_count(game: ArcadeGame) -> int:
	return game.eggs.filter(func(egg): return egg.has_snake).size()
func open_point(game: ArcadeGame) -> Vector2:
	for attempt in range(500):
		var point := game.world.free_point(26,true)
		if game.world.step_clear(point,point+Vector2(210,0)) and game.world.step_clear(point,point+Vector2(40,85)): return point
	return game.world.bounds.get_center()

func run() -> void:
	root.size = Vector2i(960,540)
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = ArcadeProfile.new()
	game.profile.powerup_tutorials = [true,true,true]
	game.profile.save_path = SAVE
	game.profile.coins = 100
	game.guards_enabled = false
	game.use_fixed_seed = true
	root.add_child(game)
	await tick(3)
	expect(game.profile.free_selection and game.ui.map_buttons.all(func(b): return not b.disabled),"A fresh save must expose every map without grinding")
	game._select_map(4)
	game._select_level(4)
	expect(game.selected_map == 4 and game.selected_level == 4 and game.ui.room_buttons.all(func(b): return not b.disabled),"All four room buttons must work even in a never-unlocked map")
	game._request_round(4,4)
	await tick(70)
	expect(game.running and game.profile.coins == 100 and game.selected_level == 4,"One start click on map four/room four must preserve the wallet and begin play")
	game.begin_round(4,4)
	expect(game.running and game.current_map == 4 and game.current_level == 4,"The selected non-first room must actually launch")
	game.abandon_round()
	for map_index in range(1,5):
		for room in range(1,5):
			game.begin_round(room,map_index)
			await tick(3)
			expect(hidden_count(game) == (room if map_index == 1 and room > 1 else 0),"Only chicken rooms 2/3/4 may hide exactly 2/3/4 snake eggs")
			game.abandon_round()
	game.begin_round(2,1)
	await tick(3)
	game.set_process(false)
	for hen in game.hens: hen.set_physics_process(false)
	game._process(20.0)
	expect(game.snakes.is_empty() and hidden_count(game) == 2,"Unpicked hidden eggs must never turn into timed snake spawns")
	game._spawn_batch(1000)
	game._spawn_egg_at(game.world.free_point(18,true),true)
	expect(hidden_count(game) == 2,"A golden reward at the ground cap must not replace a hidden snake egg")
	var egg: ArcadeEgg = game.eggs.filter(func(value): return value.has_snake)[0]
	for other: ArcadeEgg in game.eggs.duplicate():
		if other != egg:
			game.eggs.erase(other)
			other.queue_free()
	game.player.position = egg.position
	game.score = 10
	game.chain = 9
	game.combo_left = 2.2
	game.collected = 5
	game.protection_left = 0
	game.player.invulnerable = false
	expect(game.collect_at(egg.position),"Nearby left-click must release the snake hidden in that egg")
	expect(game.score == 10 and game.collected == 5 and game.snakes.size() == 1,"Snake eggs must not award normal egg points or phantom harvest")
	var snake: ArcadeSnake = game.snakes[0]
	var age := snake.age
	game.toggle_pause()
	await tick(20)
	expect(is_equal_approx(snake.age,age),"Pausing must freeze burst and dash animations")
	game.toggle_pause()
	await tick(110)
	expect(game.running and game.score == 7 and game.chain == 0 and game.player.invulnerable,"A snake bump must cost three points and the chain, grant immunity, and keep the round playable")
	game._on_snake_hit()
	expect(game.score == 7,"Immunity must prevent repeated snake penalties")
	var origin := open_point(game)
	game.player.position = origin+Vector2(40,0)
	game.player.invulnerable = false
	game._release_snake(origin)
	snake = game.snakes.back()
	var locked := snake.direction
	game.player.position = origin+Vector2(40,85)
	await tick(115)
	expect(is_instance_valid(snake) and snake.direction == locked and absf(snake.position.y-origin.y) < 0.01,"A sidestepped snake must keep its locked straight route instead of homing")
	expect(game.score == 7,"Sidestepping must avoid the penalty")
	# Walls stop the dash instead of allowing snakes to pass through cover.
	var cover: Rect2 = game.world.solids[0]
	var wall_snake := ArcadeSnake.new()
	wall_snake.position = Vector2(cover.position.x-36,cover.get_center().y)
	wall_snake.direction = Vector2.RIGHT
	game.world.add_child(wall_snake)
	await tick(110)
	expect(not is_instance_valid(wall_snake) or wall_snake.retiring,"Snakes must retire when they hit a crate")
	game.abandon_round()
	game.set_process(true)
	game.begin_round(1,4)
	await tick(3)
	var patch: ArcadeNest = game.nests[0]
	expect(patch.theme_index == 3 and patch.has_node("VegetableBasket") and patch.get_node("VegetableBasket") is Sprite2D,"The garden resource station must use a vegetable basket")
	patch.refill()
	expect(patch.plant_growth[0] == 0.0,"Refilling vegetables must begin the rising-from-soil animation")
	patch._process(1.0)
	expect(patch.plant_growth.all(func(value): return value == 1.0),"Every cabbage must finish its growth animation")
	game.player.position = patch.position+Vector2(0,30)
	var stock := patch.stock
	expect(game.collect_at(patch.position) and patch.stock == stock-1,"Garden harvest must retain instant near-player left-click collection")
	game.profile.save_progress()
	var reload := ArcadeProfile.new()
	reload.free_selection = true
	reload.save_path = SAVE
	reload.load_progress()
	expect(reload.active_map == 4 and reload.coins == game.profile.coins,"Reloading a freely selected map must keep its map identity and wallet")
	game.queue_free()
	await tick(2)
	DirAccess.remove_absolute(SAVE)
	if failures == 0: print("PASS: free map/room selection, randomized hidden snake counts, click-only release, pause, straight dash, sidestep, nonlethal penalty, immunity, walls, protected eggs, garden growth and free-map reload")
	quit(1 if failures else 0)
