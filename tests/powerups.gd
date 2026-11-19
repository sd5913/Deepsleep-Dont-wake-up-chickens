extends SceneTree

var failures := 0
const SAVE := "user://powerups-regression.json"

func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func tick(frames: int) -> void:
	for i in range(frames): await physics_frame
func freeze(game: ArcadeGame) -> void:
	game.set_process(false)
	for hen in game.hens:
		hen.set_physics_process(false)
		hen.sees_player = false
		hen.take_alarm()
func clear_pickups(game: ArcadeGame) -> void:
	for egg in game.eggs: egg.queue_free()
	game.eggs.clear()
	for drop in game.powerups.drops: drop.queue_free()
	game.powerups.drops.clear()
func open_point(game: ArcadeGame) -> Vector2:
	for attempt in range(1000):
		var point := game.world.free_point(28,true)
		if game.world.step_clear(point,point+Vector2(100,0)) and game.world.step_clear(point,point-Vector2(70,0)):
			return point
	expect(false,"Fixture needs an unobstructed pickup corridor")
	return game.player.position

func run() -> void:
	root.size = Vector2i(960,540)
	for map_index in range(1,5):
		for room in range(1,5):
			var expected := 0 if map_index == 1 and room == 1 else mini(map_index,3)
			expect(ArcadePowerup.available_for(map_index,room).size() == expected,"Pools must unlock at 1-2, 2-1, 3-1 and retain earlier types")
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = ArcadeProfile.new()
	game.profile.save_path = SAVE
	game.profile.coins = 123
	game.use_fixed_seed = true
	game.guards_enabled = false
	root.add_child(game)
	await tick(3)
	game.begin_round(1,1)
	freeze(game)
	game.powerups.advance(20.0)
	expect(game.powerups.drops.is_empty(),"The introductory chicken room must have no powerups")
	game.abandon_round()
	game.begin_round(2,1)
	await tick(3)
	freeze(game)
	expect(game.powerups.drops.size() == 3 and game.powerups.drops[0].kind == 0,"All three badges must be scattered before the room clock advances")
	game._process(0.01)
	expect(not paused and not game.ui.is_powerup_guide_visible(),"Distant powerups must not interrupt the opening with tutorials")
	var first := game.powerups.drops[0]
	game.player.position = first.position
	game._process(0.01)
	expect(paused and game.ui.is_powerup_guide_visible() and not first.claimed,"First contact must explain the item before its duration begins")
	var seconds := game.time_left
	var spawn_seconds := game.powerups.spawn_left
	await tick(10)
	expect(game.time_left == seconds and game.powerups.spawn_left == spawn_seconds,"Tutorial reading must not consume any round or spawn time")
	game.ui.powerup_guide_button.pressed.emit()
	expect(not paused and game.profile.powerup_tutorials[0] and not game.ui.is_powerup_guide_visible(),"Acknowledging the guide resumes once and records the explanation")
	expect(first.claimed and game.powerups.active[0] == 6.0,"Acknowledging first contact must activate the full effect without another click or movement")
	var reloaded := ArcadeProfile.new()
	reloaded.save_path = SAVE
	reloaded.load_progress()
	expect(reloaded.powerup_tutorials == [true,false,false] and reloaded.coins == 123,"Guide state must persist without changing the wallet")
	expect(not game._maybe_show_powerup_guide(),"An acknowledged type must not interrupt the player again")
	clear_pickups(game)
	game.powerups.clear()
	var origin := open_point(game)
	game.player.position = origin
	var badge := game.powerups.spawn_at(0,origin+Vector2(45,0))
	expect(not game.collect_at(badge.position) and not badge.claimed,"Clicking a powerup must not activate it")
	game.powerups.collect_touching()
	expect(not badge.claimed and game.can_collect_point(badge.position),"The manual egg radius must not automatically collect a powerup that has not been touched")
	game.player.position = badge.position
	game.powerups.collect_touching()
	expect(badge.claimed and game.powerups.active[0] == 6.0,"Walking over a learned powerup must activate it without input")
	game.player.position = origin
	game._spawn_egg_at(origin+Vector2(60,0),false)
	game._spawn_egg_at(origin-Vector2(60,0),true)
	game._spawn_egg_at(origin+Vector2(90,0),false)
	expect(game.collect_at(origin+Vector2(60,0)) and game.score == 12 and game.collected == 2,"Contact-activated double must apply to ordinary and gold items without duplicating collected count")
	expect(game.eggs.size() == 1,"Double must not change pickup distance")
	game.profile.powerup_tutorials[1] = true
	var basket := game.powerups.spawn_at(1,origin+Vector2(45,0))
	expect(not game.collect_at(basket.position) and not basket.claimed,"A basket must also require contact rather than a click")
	game.player.position = basket.position
	game.powerups.collect_touching()
	expect(basket.claimed and game.eggs.size() == 1,"Basket activation must not automatically collect eggs")
	game.player.position = origin
	expect(game.collect_at(origin+Vector2(90,0)) and game.eggs.is_empty(),"After touching the basket, left-click must collect eggs inside the expanded ring")
	expect(is_equal_approx(game.pickup_radius(),94.5) and game.pickup_circle.radius == game.pickup_radius(),"Visual and actual pickup radius must expand together")
	game.chain = 48
	expect(game.multiplier() == 8,"The existing 4x combo and double badge must combine to 8x")
	game.powerups.advance(2.0)
	game.powerups.take(game.powerups.spawn_at(0,origin+Vector2(10,0)))
	expect(game.powerups.active[0] == 6.0,"Duplicate badge must refresh to six seconds, not accumulate duration")
	game.powerups.advance(6.1)
	expect(game.pickup_radius() == 70.0 and game.multiplier() == 4,"Effects must expire to the purchased base radius and original combo")
	game.profile.upgrades[0] = 2
	game.powerups.take(game.powerups.spawn_at(1,origin+Vector2(10,0)))
	expect(is_equal_approx(game.pickup_radius(),78.0*1.35),"Basket must multiply the upgraded radius without changing upgrade levels")
	game.powerups.clear()
	expect(game.profile.upgrades[0] == 2 and game.pickup_radius() == 78.0,"Clearing temporary buffs must preserve purchased upgrades")
	clear_pickups(game)
	game.profile.upgrades = [0,0,0]
	var cover: Rect2 = game.world.solids[0]
	game.player.position = cover.position+Vector2(-6,12)
	var blocked := cover.position+Vector2(12,-6)
	var blocked_drop := game.powerups.spawn_at(0,blocked)
	game.powerups.collect_touching()
	expect(game.player.position.distance_to(blocked) < ArcadePowerups.CONTACT_RADIUS/game.camera.zoom.x and not blocked_drop.claimed,"Nearby powerups across cover must not count as contact")
	clear_pickups(game)
	game.abandon_round()
	game.begin_round(1,3)
	await tick(3)
	freeze(game)
	game.profile.powerup_tutorials = [true,true,true]
	game.protection_left = 0.0
	game.player.invulnerable = false
	game.guards_enabled = true
	game.alert.level = 65
	game.hens[0].sees_player = true
	game.powerups.take(game.powerups.spawn_at(2,game.player.position+Vector2(15,0)))
	game._update_guards(0.1)
	expect(game.player.concealed and not game.player.invulnerable and game.alert.level > 0 and game.alert.level <= 65,"Stealth must suppress detection without granting damage immunity or clearing alert")
	game.score = 50
	game.chain = 10
	game._on_snake_hit()
	expect(game.score == 47 and game.chain == 0,"Stealth must not prevent the existing snake penalty")
	game.player.invulnerable = false
	game.snake_immunity_left = 0
	game._spawn_farmer()
	game.farmer.position = game.player.position+Vector2(20,0)
	game.farmer.last_known_position = game.player.position
	for i in range(4): game.farmer._physics_process(0.8)
	expect(game.running and game.farmer.leaving and not game.farmer.sees_player,"A concealed actor cannot be captured and the farmer must forget after three seconds")
	var timer := game.powerups.active[2]
	game.toggle_pause()
	await tick(10)
	expect(game.powerups.active[2] == timer,"Normal pause must freeze active powerup duration")
	game.toggle_pause()
	game.powerups.advance(4.1)
	expect(not game.player.concealed,"Stealth must end after its own timer")
	game.abandon_round()
	game.guards_enabled = false
	game.begin_round(1,4)
	await tick(3)
	freeze(game)
	expect(game.powerups.drops.size() == 4,"Garden must start with all four powerups on the ground")
	game.powerups.advance(30.0)
	expect(game.powerups.drops.size() == 4 and game.powerups.spawned == 4,"Opening stock must not be followed by surprise clustered spawn waves")
	for drop: ArcadePowerup in game.powerups.drops.duplicate(): game.powerups.take(drop)
	game.powerups.advance(0.1)
	expect(game.powerups.spawned == 4 and game.powerups.drops.is_empty(),"The original four-item room budget must remain bounded")
	var wallet := game.profile.coins
	game.finish_round()
	expect(game.powerups.active == [0.0,0.0,0.0] and not game.player.concealed,"Round end must clear all temporary effects")
	expect(game.profile.coins == wallet+game.score/5,"Temporary buffs must leave the original coin settlement intact")
	for seed_value in [7,19]:
		game.fixed_seed = seed_value
		for map_index in range(1,5):
			for room in range(1,5):
				game.begin_round(room,map_index)
				expect(game.powerups.drops.size() == game.powerups.spawn_limit,"Every eligible room must have its complete stock at time zero")
				for i in range(game.powerups.drops.size()):
					var drop := game.powerups.drops[i]
					expect(game.world.is_free(drop.position,18.0/game.camera.zoom.x,true),"Opening powerups must be on free floor, outside nests and colliders")
					expect(not game.powerups.touching(drop),"Opening layout must not activate a powerup on the spawn position")
					for j in range(i):
						expect(drop.position.distance_to(game.powerups.drops[j].position)*game.camera.zoom.x >= ArcadePowerups.MIN_SPACING-0.01,"Every pair must keep its visible spacing on every map and room size")
				game.abandon_round()
	game.queue_free()
	await tick(2)
	DirAccess.remove_absolute(SAVE)
	if failures == 0: print("PASS: time-zero scattered stock across 16 rooms, visible minimum spacing, contact-only activation, no auto eggs, contact tutorials, persisted guides, score/radius, expiry/refresh, cover, stealth versus snake damage, farmer forgetting and settlement")
	quit(1 if failures else 0)
