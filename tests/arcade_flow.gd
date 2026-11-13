extends SceneTree

var failures := 0
const SAVE_PATH := "user://arcade-regression-only.json"

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func tick(frames: int) -> void:
	for i in range(frames): await process_frame

func click(game: ArcadeGame, button: int, point: Vector2) -> void:
	var screen_point := game.get_canvas_transform() * point
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = screen_point
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	root.size = Vector2i(960,540)
	var profile := ArcadeProfile.new()
	profile.save_path = SAVE_PATH
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = profile
	game.use_fixed_seed = true
	game.guards_enabled = false
	root.add_child(game)
	await tick(3)
	expect(game.ui.overlay.visible and not game.running,"Start menu must be visible before the timer starts")
	game.begin_round(1)
	await tick(3)
	expect(game.round_seconds == 60.0 and game.time_left > 59.5,"A round must start at one minute")
	expect(game.pickup_radius() == 70.0,"Base pickup diameter must be half the previous size")
	expect(game.hens.size() == 4,"Stage one must start with four patrolling hens")
	var movement_origin := game.world.free_point(30,true)
	for attempt in range(300):
		if game.world.step_clear(movement_origin,movement_origin+Vector2(0,-90)) and game.world.step_clear(movement_origin,movement_origin+Vector2(0,90)): break
		movement_origin = game.world.free_point(30,true)
	game.player.position = movement_origin
	var art: CoopCharacterArt = game.player.get_node("Art")
	for direction in ["move_up","move_down"]:
		game.player.position = movement_origin
		Input.action_press(direction)
		await tick(3)
		var first_frame: AtlasTexture = art._sprite.texture
		expect(first_frame.atlas == CoopCharacterArt.RUN_ATLAS,"Vertical movement must use actual running frames")
		expect(first_frame.region.position.y == (491 if direction == "move_up" else 51),"W/S must show the corresponding back/front run")
		await tick(7)
		expect(art._sprite.texture.region != first_frame.region,"Leg poses must alternate during vertical movement")
		game.player.show_feed_toss()
		await tick(3)
		expect(art._sprite.texture.atlas == CoopCharacterArt.RUN_ATLAS,"Collecting while running must not freeze the legs")
		expect(game.player.position.y < movement_origin.y if direction == "move_up" else game.player.position.y > movement_origin.y,"W/S must move the actor as well as animate it")
		Input.action_release(direction)
		await tick(2)
		expect(art._sprite.texture.atlas == CoopCharacterArt.ATLAS,"Stopping must restore the idle pose")
	game.begin_round(4)
	expect(game.current_level == 1,"Locked stages must not start")
	expect(game.eggs.size() >= 20,"The first round must start with plentiful ground eggs")
	expect(game.nests.size() >= 4,"Random nests should be available")
	var egg: ArcadeEgg = game.eggs[0]
	var point := egg.position
	game.player.position = point
	await tick(8)
	expect(game.collected == 0,"Walking onto eggs must not auto-collect")
	game._update_pickup_feedback(point)
	expect(egg.highlighted,"Hover feedback must highlight a reachable egg without collecting it")
	await click(game,MOUSE_BUTTON_RIGHT,point)
	expect(game.collected == 0,"Right click must not pick up eggs")
	await click(game,MOUSE_BUTTON_LEFT,point)
	expect(game.collected == 1 and game.score == 1,"Nearby left click must immediately collect and score")
	var unchanged := game.score
	if game._pickup_target_at(point) == null:
		game.collect_at(point)
		expect(game.score == unchanged,"An empty target cannot yield another egg")
	var far: ArcadeEgg
	for candidate in game.eggs:
		if game.player.position.distance_to(candidate.position) > game.pickup_radius()+60/game.camera.zoom.x:
			far = candidate
			break
	expect(far != null,"The map should contain eggs outside the local pickup ring")
	if far != null:
		var before_score := game.score
		game._update_pickup_feedback(far.position)
		expect(not far.highlighted,"A distant egg must not show the collectible highlight")
		expect(not game.collect_at(far.position),"Distant eggs must be rejected")
		expect(game.score == before_score and game.eggs.has(far),"Rejected pickup must not remove an egg or score")
	var nest: ArcadeNest = game.nests[0]
	game.player.position = nest.position+Vector2(game.pickup_radius()+50,0)
	var distant_stock := nest.stock
	expect(not game.collect_at(nest.position) and nest.stock == distant_stock,"Distant nests must not dispense eggs")
	game.player.position = nest.position+Vector2(0,30)
	game._update_pickup_feedback(nest.position)
	expect(nest.highlighted,"A nearby stocked nest must show hover feedback")
	var stock := nest.stock
	var collected_before := game.collected
	for i in range(stock): expect(game.collect_at(nest.position),"Each nest click should immediately yield one egg")
	expect(game.collected == collected_before+stock and nest.stock == 0,"Visible nest stock must decrease with every click")
	expect(not game.collect_at(nest.position),"Empty nests must not yield phantom eggs")
	# Clearing the field should not grant any collection and must be replenished.
	for other: ArcadeEgg in game.eggs.duplicate():
		game.eggs.erase(other)
		other.queue_free()
	collected_before = game.collected
	await tick(500)
	expect(game.eggs.size() > 0 and game.eggs.size() <= 66,"Random spawning must replenish eggs and respect a cap")
	expect(game.collected == collected_before,"Spawning must not count as collecting")
	expect(nest.stock >= 2 and nest.stock <= 6,"Empty nests must refill with a visible random stock")
	var time_before := game.time_left
	game.toggle_pause()
	await tick(5)
	expect(is_equal_approx(game.time_left,time_before),"Pausing must stop the round timer")
	expect(not game.collect_at(game.eggs[0].position),"Paused rounds must not collect")
	game.toggle_pause()
	game.time_left = 10.1
	game._process(0.2)
	expect(game.running and game.ui.time_label.text == "0:10" and game._last_seconds_announced,"The final ten seconds must show a cue while collection remains active")
	# Settlement is once per completed round; score is independent from currency.
	game.score = 125
	game.collected = 80
	game.time_left = 0.01
	game._process(0.02)
	expect(not game.running and game.ui.overlay.visible,"Timeout must open settlement instead of failing the run")
	expect(profile.coins == 25 and profile.best[0] == 125 and profile.unlocked == 2,"Settlement must award currency, best score and next stage")
	game.finish_round()
	expect(profile.coins == 25,"Settlement must not award twice")
	expect(profile.buy(0) and profile.coins == 5 and profile.upgrades[0] == 1,"A purchased upgrade must spend currency and persist a level")
	expect(not profile.buy(1),"Insufficient funds must not buy an upgrade")
	var reloaded := ArcadeProfile.new()
	reloaded.save_path = SAVE_PATH
	reloaded.load_progress()
	expect(reloaded.coins == 5 and reloaded.upgrades[0] == 1 and reloaded.best[0] == 125,"Progress must survive reloading")
	var prior_area: float = game.world.arena_size.x*game.world.arena_size.y
	for level in range(2,5):
		game.begin_round(level)
		await tick(3)
		var area: float = game.world.arena_size.x*game.world.arena_size.y
		expect(area > prior_area,"Each unlocked stage must have a physically larger world")
		prior_area = area
		for ground: ArcadeEgg in game.eggs:
			expect(game.world.is_free(ground.position,12,true),"Eggs must not spawn inside obstacles or nests")
		if level == 2:
			expect(game.pickup_radius() == 74.0,"Reach upgrades must preserve the halved radius scale")
			var boundary_origin := Vector2.ZERO
			var radius := game.pickup_radius()
			for attempt in range(300):
				boundary_origin = game.world.free_point(20,true)
				if game.world.step_clear(boundary_origin,boundary_origin+Vector2(radius+6,0)): break
			var inside := boundary_origin+Vector2(radius-6,0)
			var outside := boundary_origin+Vector2(radius+6,0)
			game._spawn_egg_at(inside,false)
			game._spawn_egg_at(outside,false)
			var outside_egg: ArcadeEgg = game.eggs.back()
			game.player.position = boundary_origin
			expect(game.can_collect_point(inside) and not game.can_collect_point(outside),"Circle boundary must distinguish reachable and distant eggs")
			expect(game.collect_at(inside),"The egg just inside the ring must be collectible")
			expect(game.eggs.has(outside_egg) and not outside_egg.claimed,"Gather upgrades must not pull a neighboring egg from outside the ring")
			var gather_point := game.world.free_point(20,true)
			for attempt in range(100):
				if game.world.is_free(gather_point+Vector2(20,0),12,true): break
				gather_point = game.world.free_point(20,true)
			game._spawn_egg_at(gather_point,false)
			game._spawn_egg_at(gather_point+Vector2(20,0),false)
			var before := game.collected
			game.player.position = gather_point
			game.collect_at(gather_point)
			expect(game.collected >= before+2,"Gather upgrade must collect adjacent eggs from one manual click")
		if level >= 3:
			game._process(game.round_seconds*0.5-1.0)
			expect(game.golden_count == 0,"Golden hens should not appear before halfway")
			game._process(2.0)
			expect(game.golden_count == 1,"Later stages should introduce a golden hen after halfway")
			game._spawn_batch(1000)
			var target := game.world.free_point(18,true)
			game._spawn_egg_at(target,true)
			var gold: ArcadeEgg
			for candidate in game.eggs:
				if candidate.golden: gold = candidate
			expect(gold != null,"A full ordinary field must still allow golden eggs")
			if gold != null:
				var old_score := game.score
				game.player.position = gold.position
				game.collect_at(gold.position)
				expect(game.score >= old_score+5,"Golden eggs must be worth more")
		if level == 4:
			game._process(game.round_seconds*0.25)
			expect(game.golden_count == 2,"Final stage should add a second golden hen later")
		game.finish_round()
		await tick(2)
	# Preserve the original hen vision, alarm and farmer pressure in the new mode.
	game.guards_enabled = true
	game.begin_round(1)
	await tick(5)
	for other in game.hens: other.set_physics_process(false)
	var guard: ArcadeHen = game.hens[0]
	guard.roaming_enabled = false
	var origin := game.world.free_point(30,true)
	for attempt in range(200):
		if game.world.step_clear(origin,origin+Vector2(80,0)): break
		origin = game.world.free_point(30,true)
	guard.position = origin
	guard._facing = Vector2.RIGHT
	game.player.position = origin+Vector2(80,0)
	guard.set_physics_process(true)
	await tick(4)
	expect(game.player.invulnerable and not guard.sees_player and not guard.take_alarm() and game.alert.level == 0,"Opening protection must suppress sight, clucks and alert")
	var grace_left := game.protection_left
	game.toggle_pause()
	await tick(10)
	expect(is_equal_approx(game.protection_left,grace_left),"Pausing must not consume opening protection")
	game.toggle_pause()
	await tick(155)
	expect(game.player.invulnerable and game.alert.level == 0,"The opening grace must last the full three seconds")
	await tick(30)
	expect(guard.sees_player and game.alert.level > 0,"Patrolling hens must see the player and raise global alert")
	expect(guard.get_node("Vision").polygon.size() > 3,"Hen must retain its occluded vision fan")
	expect(guard.patrol_speed > 64.0,"Hen patrol should be slightly faster than the old baseline")
	var cover: Rect2 = game.world.solids[0]
	guard.position = cover.get_center()-Vector2(0,80)
	guard._facing = Vector2.DOWN
	game.player.position = cover.get_center()+Vector2(0,80)
	await tick(4)
	expect(not guard.sees_player,"Crates must block hen sight")
	game.player.position = cover.position+Vector2(-20,25)
	var blocked_point := cover.position+Vector2(25,-20)
	expect(game.player.position.distance_to(blocked_point) < game.pickup_radius(),"The occlusion check must target a point inside the smaller pickup radius")
	expect(not game.can_collect_point(blocked_point),"Crates must block otherwise nearby pickups")
	guard.set_physics_process(false)
	guard.sees_player = false
	game.alert.level = 65
	await tick(125)
	expect(is_instance_valid(game.farmer),"High alert must summon the original farmer")
	if is_instance_valid(game.farmer):
		game.profile.unlocked = 1
		game.score = 50
		game.farmer.position = game.player.position
		await tick(4)
		expect(not game.running and game.last_result.get("caught",false),"Capture must end the round and preserve a settlement")
		expect(game.profile.unlocked == 1,"Capture must not unlock a new stage early")
	for stream in game.audio.get_children(): expect(not stream.playing,"Audio should remain off")
	# Corrupt/old saves should recover to safe defaults rather than crash.
	var bad := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	bad.store_string("bad json")
	bad.close()
	var recovered := ArcadeProfile.new()
	recovered.save_path = SAVE_PATH
	recovered.load_progress()
	expect(recovered.coins == 0 and recovered.unlocked == 1,"Corrupt save should fall back to defaults")
	game.audio.stop_all()
	OS.delay_msec(200)
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	if failures == 0: print("PASS: one-minute rounds, four patrol hens, halved pickup reach, up/down run cycles, hover feedback, countdown, local collection, alarms/capture, nest stocks/refills, settlement, upgrades, growing stages and golden hens")
	quit(1 if failures > 0 else 0)
