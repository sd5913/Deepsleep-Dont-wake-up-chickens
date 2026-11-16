class_name ArcadeGame
extends Node2D

const PLAYER := preload("res://scenes/player.tscn")
const AUDIO := preload("res://scenes/round_audio.tscn")
const CHICKEN := preload("res://scenes/chicken.tscn")
const FARMER := preload("res://scenes/farmer.tscn")
const FARMER_SCRIPT := preload("res://scenes/arcade/farmer.gd")
const HEN_SCRIPT := preload("res://scenes/arcade/hen.gd")
const RANGE_SCRIPT := preload("res://scenes/arcade/pickup_range.gd")
const EFFECT := preload("res://scenes/arcade/effect.gd")
const SNAKE := preload("res://scenes/arcade/snake.gd")
const ANIMAL_ART := preload("res://scenes/arcade/animal_art.gd")
@export_range(10.0,300.0,1.0) var round_seconds := 60.0
@export var use_fixed_seed := false
@export var fixed_seed := 7
@export var guards_enabled := true
@export var free_stage_select := true
@export_range(30.0,220.0,5.0) var base_pickup_radius := 70.0
var profile: ArcadeProfile
var selected_level := 1
var selected_map := 1
var current_map := 1
var transitioning := false
var current_level := 1
var running := false
var score := 0
var collected := 0
var chain := 0
var combo_left := 0.0
var time_left := 60.0
var world: ArcadeWorld
var player: CoopPlayer
var ui: ArcadeUI
var camera: Camera2D
var audio: CoopRoundAudio
var eggs: Array[ArcadeEgg] = []
var nests: Array[ArcadeNest] = []
var hens: Array[ArcadeHen] = []
var spawn_left := 0.0
var golden_count := 0
var last_result := {}
var alert: CoopAlert
var farmer: ArcadeFarmer
var pickup_circle: Node2D
var _farmer_warning := 0.0
var _farmer_armed := true
var _farmer_cooldown_left := 0.0
var _reported_position := Vector2.ZERO
var _last_seconds_announced := false
var protection_left := 0.0
var snake_immunity_left := 0.0
var snakes: Array[ArcadeSnake] = []
var stage_settings := {}
var _was_seen := false
var _detection_cooldown := 0.0
var _shake_left := 0.0
var _shake_duration := 0.28
var _shake_strength := 0.0
var _shake_clock := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if profile == null:
		profile = ArcadeProfile.new()
		profile.free_selection = free_stage_select
		profile.load_progress()
	profile.free_selection = free_stage_select
	selected_level = profile.unlocked
	selected_map = mini(profile.active_map+1,profile.unlocked_maps) if profile.map_complete and profile.active_map < 4 else profile.active_map
	if profile.map_complete: selected_level = 1
	_rng.randomize()
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	ui = ArcadeUI.new()
	ui.round_duration = ceili(round_seconds)
	add_child(ui)
	profile.storage_status_changed.connect(_on_storage_status_changed)
	ui.update_storage_status(profile)
	ui.start_requested.connect(_request_round)
	ui.map_selection_changed.connect(_select_map)
	ui.restart_requested.connect(_restart_map)
	ui.pause_requested.connect(toggle_pause)
	ui.abandon_requested.connect(abandon_round)
	ui.selection_changed.connect(_select_level)
	ui.upgrade_requested.connect(_buy_upgrade)
	audio = AUDIO.instantiate()
	add_child(audio)
	# Audio is intentionally off for this iteration.
	for stream in audio.get_children(): stream.volume_db = -80
	_build_world(selected_level)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level,{},false,selected_map)
	_update_hud()

func _select_level(level: int) -> void:
	if running or transitioning or level < 1 or level > 4: return
	if not free_stage_select and (level != profile.unlocked or selected_map != profile.active_map): return
	selected_level = level
	_build_world(level)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level,last_result,false,selected_map)
	_update_hud()

func _buy_upgrade(index: int) -> void:
	if running or transitioning or index < 0 or index > 2 or not profile.can_visit_map(selected_map): return
	var entering := selected_map != profile.active_map or profile.map_complete
	var price: int = ArcadeProfile.COSTS[0] if entering else profile.cost(index)
	if price < 0 or profile.coins < price: return
	if entering:
		profile.start_map(selected_map)
		if free_stage_select: profile.prepare_room(selected_level)
		last_result = {"entered_map":true}
	profile.buy(index)
	_build_world(selected_level)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level,last_result,false,selected_map)

func _select_map(index: int) -> void:
	if running or transitioning or not profile.can_visit_map(index): return
	selected_map = index
	selected_level = profile.unlocked if index == profile.active_map and not profile.map_complete else 1
	_build_world(selected_level)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level,last_result,false,selected_map)
	_update_hud()

func _request_round(level: int, map_index: int) -> void:
	if running or transitioning or not profile.can_visit_map(map_index) or level < 1 or level > 4: return
	var entering := map_index != profile.active_map or profile.map_complete
	if not free_stage_select:
		if entering and level != 1: return
		if not entering and level != profile.unlocked: return
	transitioning = true
	ui.show_transition(map_index,level)
	await get_tree().create_timer(1.8 if map_index == 1 and level >= 2 else 1.0).timeout
	begin_round(level,map_index)
	ui.hide_transition()
	transitioning = false

func _restart_map(map_index: int) -> void:
	if running or transitioning or map_index != profile.active_map: return
	profile.start_map(map_index)
	selected_map = map_index
	selected_level = 1
	last_result = {"entered_map":true}
	_build_world(1)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,1,last_result,false,selected_map)
	_update_hud()

func _build_world(level: int) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	eggs.clear()
	nests.clear()
	hens.clear()
	snakes.clear()
	farmer = null
	_was_seen = false
	_detection_cooldown = 0.0
	_reset_shake()
	_farmer_warning = 0.0
	_farmer_armed = true
	_farmer_cooldown_left = 0.0
	protection_left = 0.0
	snake_immunity_left = 0.0
	world = ArcadeWorld.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var seed_value := fixed_seed if use_fixed_seed else _rng.randi()
	world.theme_index = selected_map
	stage_settings = ArcadeDifficulty.for_stage(selected_map,level)
	world.build(level,seed_value)
	current_level = level
	current_map = selected_map
	camera.position = world.arena_size * 0.5
	camera.zoom = Vector2.ONE * 960.0 / world.arena_size.x
	player = PLAYER.instantiate()
	player.position = Vector2(world.bounds.get_center().x,world.bounds.end.y-45)
	player.move_speed = 330.0
	world.add_child(player)
	pickup_circle = Node2D.new()
	pickup_circle.set_script(RANGE_SCRIPT)
	pickup_circle.radius = pickup_radius()
	player.add_child(pickup_circle)
	player.move_child(pickup_circle,0)
	alert = CoopAlert.new()
	alert.sight_gain_per_second = stage_settings.sight_gain
	alert.cluck_gain = stage_settings.cluck_gain
	alert.calm_delay = stage_settings.calm_delay
	alert.decay_per_second = stage_settings.decay
	world.add_child(alert)
	for i in range(2 + level*2):
		var point := world.free_point(52,true)
		if point == Vector2.INF: break
		world.nest_points.append(point)
		var nest := ArcadeNest.new()
		nest.position = point
		nest.rng.seed = world.rng.randi()
		nest.refill_speed = pow(0.86,_buffs()[2])
		nest.theme_index = current_map-1
		world.add_child(nest)
		nests.append(nest)
	for i in range(stage_settings.animals): _add_hen(false)
	_spawn_batch(18+level*14)
	_seed_snake_eggs()

func begin_round(level: int, map_index := 0) -> void:
	if running: return
	var target_map := selected_map if map_index == 0 else map_index
	if not profile.can_visit_map(target_map) or level < 1 or level > 4: return
	if target_map != profile.active_map or profile.map_complete:
		if not free_stage_select and level != 1: return
		profile.start_map(target_map)
	if not profile.prepare_room(level): return
	selected_map = target_map
	get_tree().paused = false
	running = false
	_build_world(level)
	selected_level = level
	score = 0
	collected = 0
	chain = 0
	combo_left = 0.0
	golden_count = 0
	time_left = round_seconds
	protection_left = 3.0
	player.invulnerable = true
	spawn_left = world.rng.randf_range(0.4,0.9)
	last_result = {}
	_last_seconds_announced = false
	running = true
	ui._map_selected = current_map
	ui.hide_menu()
	ui.announce("开局保护 3 秒，先移动到合适的位置！","3 seconds of protection. Find a good starting position!")
	_update_hud()

func _process(delta: float) -> void:
	if not running or get_tree().paused: return
	time_left = maxf(0,time_left-delta)
	if time_left <= 0:
		finish_round()
		return
	protection_left = maxf(0.0,protection_left-delta)
	snake_immunity_left = maxf(0.0,snake_immunity_left-delta)
	player.invulnerable = protection_left > 0.0 or snake_immunity_left > 0.0
	_update_guards(delta)
	if not running: return
	_update_shake(delta)
	_update_pickup_feedback(get_global_mouse_position())
	if time_left <= 10.0 and not _last_seconds_announced:
		_last_seconds_announced = true
		ui.announce("最后 10 秒，抓紧收集！","10 seconds left. Keep collecting!")
	combo_left = maxf(0,combo_left-delta)
	if combo_left == 0: chain = 0
	spawn_left -= delta
	if spawn_left <= 0:
		var desired := 18+current_level*14
		var count := world.rng.randi_range(2,5)
		if eggs.size() < desired/2: count += 6
		_spawn_batch(count)
		spawn_left = world.rng.randf_range(0.45,1.1)
	var elapsed := round_seconds-time_left
	if current_map != 3 and current_level >= 3 and golden_count == 0 and elapsed >= round_seconds*0.5:
		_add_hen(true)
		golden_count = 1
		ui.announce("黄金伙伴来了！金色收集物价值更高。","Golden visitor! Its golden items are worth more.")
	if current_map != 3 and current_level == 4 and golden_count == 1 and elapsed >= round_seconds*0.75:
		_add_hen(true)
		golden_count = 2
		ui.announce("第二只黄金伙伴加入了农场！","A second golden visitor has arrived!")
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_round"):
		if running: toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not running or get_tree().paused: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		collect_at(get_canvas_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func collect_at(point: Vector2) -> bool:
	if not running or get_tree().paused: return false
	var target := _pickup_target_at(point)
	if target is ArcadeEgg:
		var closest: ArcadeEgg = target
		if not can_collect_point(closest.position):
			ui.announce("只能收集身边的物品；被木箱挡住时请绕过去。","Move closer; crates can block a pickup.")
			return false
		# The player's ring is the collection area, regardless of the clicked egg.
		for other: ArcadeEgg in eggs.duplicate():
			if can_collect_point(other.position): _collect_egg(other)
		return true
	if target is ArcadeNest:
		var nest: ArcadeNest = target
		if not can_collect_point(nest.position):
			ui.announce("走近资源点，再连续点击收集。","Move closer, then left-click the resource patch.")
			return false
		if nest.take():
			_award(nest.position+Vector2(0,-8),false)
			return true
		ui.announce("这里正在补货，先收集地面的物品吧。","Refilling. Collect some nearby ground items meanwhile.")
	return false

func _pickup_target_at(point: Vector2) -> Node2D:
	var closest: ArcadeEgg
	var reachable: ArcadeEgg
	var distance := pow(24.0/camera.zoom.x,2)
	var reachable_distance := distance
	for egg in eggs:
		if egg.claimed: continue
		var candidate := egg.position.distance_squared_to(point)
		if candidate <= distance:
			distance = candidate
			closest = egg
		if candidate <= reachable_distance and can_collect_point(egg.position):
			reachable_distance = candidate
			reachable = egg
	if reachable != null: return reachable
	if closest != null:
		return closest
	for nest in nests:
		if Rect2(nest.position+Vector2(-58,-54),Vector2(116,78)).has_point(point):
			return nest
	return null

func _update_pickup_feedback(point: Vector2) -> void:
	var target := _pickup_target_at(point)
	var reachable := is_instance_valid(target) and can_collect_point(target.position)
	if target is ArcadeNest and target.stock <= 0: reachable = false
	for egg in eggs:
		egg.modulate.a = 1.0 if can_collect_point(egg.position) else 0.68
		egg.highlighted = reachable and target is ArcadeEgg and can_collect_point(egg.position)
	for nest in nests:
		nest.highlighted = reachable and nest == target
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if reachable else Input.CURSOR_ARROW)

func _clear_pickup_feedback() -> void:
	for egg in eggs: egg.highlighted = false
	for nest in nests: nest.highlighted = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _collect_egg(egg: ArcadeEgg) -> void:
	if egg.claimed or not eggs.has(egg) or not can_collect_point(egg.position): return
	egg.claimed = true
	eggs.erase(egg)
	if egg.has_snake:
		_release_snake(egg.position)
	else: _award(egg.position,egg.golden)
	egg.queue_free()

func _seed_snake_eggs() -> void:
	# Fixed hidden egg count, randomized locations; no timed or forced encounters.
	if current_map != 1 or current_level == 1: return
	var candidates := eggs.duplicate()
	for i in range(candidates.size()-1,0,-1):
		var j := world.rng.randi_range(0,i)
		var value = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = value
	for i in range(mini(current_level,candidates.size())): candidates[i].has_snake = true

func _release_snake(point: Vector2) -> void:
	var snake := ArcadeSnake.new()
	snake.position = point
	snake.player = player
	snake.direction = (player.position-point).normalized()
	if snake.direction.is_zero_approx(): snake.direction = Vector2.from_angle(world.rng.randf_range(0,TAU))
	snake.player_hit.connect(_on_snake_hit)
	snake.hatched.connect(_on_snake_hatched)
	world.add_child(snake)
	snakes.append(snake)
	snake.tree_exiting.connect(func(): snakes.erase(snake))
	player.show_feed_toss()
	ui.announce("捡到一枚奇怪的蛋……","Something is moving inside this egg…")

func _on_snake_hatched() -> void:
	if not running: return
	player.show_startle()
	ui.show_reaction("！小蛇！快躲！","! SNAKE! MOVE!",1.05)
	ui.announce("蛋裂开了！快侧移，小蛇马上直冲！","The egg cracked! Sidestep before the snake dashes!")
	_start_shake(2.5,0.18)

func _on_snake_hit() -> void:
	if not running or player.invulnerable: return
	var penalty := mini(3,score)
	score -= penalty
	chain = 0
	combo_left = 0.0
	snake_immunity_left = 1.2
	player.invulnerable = true
	ui.announce("被小蛇碰到！-%d 分，连击中断。" % penalty,"Snake bump! -%d points, chain broken." % penalty)
	_update_hud()

func _award(point: Vector2, gold: bool) -> void:
	var units := 2 if world.rng.randf() < _buffs()[1]*0.1 else 1
	chain += 1
	combo_left = 2.2
	var points := units * (5 if gold else 1) * multiplier()
	score += points
	collected += units
	var effect := Node2D.new()
	effect.set_script(EFFECT)
	effect.origin = point
	effect.target = player
	effect.golden = gold
	effect.number = points
	effect.theme_index = current_map-1
	effect.z_index = 5
	world.add_child(effect)
	player.show_feed_toss()
	_update_hud()

func multiplier() -> int:
	return 1 + mini(3,chain/12)

func _add_hen(gold: bool) -> void:
	if gold and current_map == 3: return
	var point := world.patrol_point(hens.size()%4)
	if point == Vector2.INF: point = world.free_point(24,true)
	if point == Vector2.INF: return
	var node = CHICKEN.instantiate()
	node.set_script(HEN_SCRIPT)
	var hen: ArcadeHen = node
	if current_map > 1:
		var body = hen.get_node("Body")
		body.set_script(ANIMAL_ART)
		body.theme_index = current_map-1
	hen.world = world
	hen.player = player
	hen.golden = gold
	hen.position = point
	hen.patrol_speed = stage_settings.patrol_speed*(1.08 if gold else 1.0)
	hen.waypoint_pause = 0.6
	hen.vision_distance = stage_settings.vision
	hen.vision_angle = stage_settings.vision_angle
	hen.set_patrol_seed(world.rng.randi())
	world.add_child(hen)
	hens.append(hen)
	hen.egg_laid.connect(_spawn_egg_at)

func pickup_radius() -> float:
	return base_pickup_radius + _buffs()[0]*4.0

func _buffs() -> Array:
	return profile.upgrades if current_map == profile.active_map and not profile.map_complete else [0,0,0]

func can_collect_point(point: Vector2) -> bool:
	if player.position.distance_squared_to(point) > pow(pickup_radius(),2): return false
	if player.position.distance_squared_to(point) < 0.01: return true
	var ray := PhysicsRayQueryParameters2D.create(player.global_position,point,2)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _update_guards(delta: float) -> void:
	_detection_cooldown = maxf(0.0,_detection_cooldown-delta)
	_farmer_cooldown_left = maxf(0.0,_farmer_cooldown_left-delta)
	if not guards_enabled: return
	if player.invulnerable:
		_was_seen = false
		for hen in hens: hen.take_alarm()
		ui.update_danger(alert.level,false,false)
		return
	var seen := 0
	var clucks := 0
	for hen in hens:
		if hen.sees_player: seen += 1
		if hen.take_alarm(): clucks += 1
	var detected := seen > 0 or (is_instance_valid(farmer) and farmer.sees_player)
	if detected and not _was_seen and _detection_cooldown == 0.0:
		_start_shake(4.0,0.28)
		ui.show_reaction("！被发现了！","! SPOTTED!",0.9)
		ui.announce("被发现了！快绕到掩体后，农夫会赶过来！","Spotted! Break sight behind cover before the farmer arrives!")
		_detection_cooldown = 1.2
	_was_seen = detected
	if seen > 0: _reported_position = player.position
	alert.advance(delta,seen,clucks,is_instance_valid(farmer) and farmer.sees_player)
	ui.update_danger(alert.level,seen > 0,is_instance_valid(farmer) and not farmer.leaving)
	if is_instance_valid(farmer): return
	if _farmer_cooldown_left > 0.0: return
	if _farmer_warning > 0.0:
		_farmer_warning = maxf(0,_farmer_warning-delta)
		if _farmer_warning == 0.0: _spawn_farmer()
	elif alert.level < stage_settings.summon_at:
		_farmer_armed = true
	elif _farmer_armed:
		_farmer_armed = false
		_farmer_warning = stage_settings.warning
		_reported_position = player.position
		ui.announce("警戒升高，农夫即将从北侧入场！","High alert! The farmer is coming from the north!")

func _spawn_farmer() -> void:
	var actor = FARMER.instantiate()
	actor.set_script(FARMER_SCRIPT)
	farmer = actor
	farmer.player = player
	farmer.alert = alert
	farmer.chase_speed = stage_settings.farmer_chase
	farmer.walk_speed = stage_settings.farmer_walk
	farmer.vision_distance = stage_settings.farmer_vision
	farmer.search_seconds = stage_settings.farmer_search
	farmer.retreat_alert_level = 28.0-stage_settings.pressure*2.0
	farmer.position = Vector2(world.bounds.get_center().x,world.bounds.position.y+25)
	farmer.home_position = farmer.position
	farmer.last_known_position = _reported_position
	farmer.player_caught.connect(func(): finish_round(true))
	farmer.player_lost.connect(_farmer_lost_player)
	farmer.departed.connect(_farmer_departed)
	world.add_child(farmer)
	ui.announce("农夫正在搜寻，利用木箱躲开视线！","Farmer searching! Break sight behind crates!")

func _farmer_lost_player() -> void:
	alert.level = minf(alert.level,40.0)
	_farmer_cooldown_left = 8.0
	_farmer_warning = 0.0
	_farmer_armed = true
	ui.announce("甩开农夫了！他已放弃追赶，趁现在继续收集。","You lost the farmer! He's giving up. Keep collecting.")
	ui.update_danger(alert.level,false,false)

func _farmer_departed() -> void:
	if is_instance_valid(farmer): farmer.queue_free()
	farmer = null
	_farmer_cooldown_left = maxf(_farmer_cooldown_left,6.0)
	_farmer_armed = true

func _spawn_batch(count: int) -> void:
	var maximum := 48+current_level*18
	for i in range(count):
		if eggs.size() >= maximum: break
		var point := world.free_point(16,true)
		if point == Vector2.INF: break
		var clear := true
		for egg in eggs:
			if egg.position.distance_to(point) < 20:
				clear = false
				break
		if clear: _spawn_egg_at(point,current_map == 3 and world.rng.randf() < 0.045+current_level*0.012)

func _spawn_egg_at(point: Vector2, gold: bool) -> void:
	if not world.is_free(point,12,true): return
	if eggs.size() >= 48+current_level*18:
		if not gold: return
		var replaced := false
		for old in eggs:
			if not old.golden and not old.has_snake:
				eggs.erase(old)
				old.queue_free()
				replaced = true
				break
		if not replaced: return
	var egg := ArcadeEgg.new()
	egg.position = point
	egg.golden = gold
	egg.theme_index = current_map-1
	egg.phase = world.rng.randf()*TAU
	egg.scale = Vector2.ONE * maxf(1.2,1.05/camera.zoom.x)
	egg.z_index = 1
	world.add_child(egg)
	eggs.append(egg)

func toggle_pause() -> void:
	if not running: return
	get_tree().paused = not get_tree().paused
	if get_tree().paused: camera.offset = Vector2.ZERO
	_clear_pickup_feedback()
	if get_tree().paused: ui.show_menu(profile,current_level,{},true,current_map)
	else: ui.hide_menu()

func abandon_round() -> void:
	_reset_shake()
	_clear_pickup_feedback()
	get_tree().paused = false
	running = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level,{},false,selected_map)

func finish_round(caught := false) -> void:
	if not running: return
	_reset_shake()
	_clear_pickup_feedback()
	running = false
	get_tree().paused = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	last_result = profile.settle(current_level,score,not caught)
	last_result["eggs"] = collected
	last_result["caught"] = caught
	selected_map = mini(current_map+1,4 if free_stage_select else profile.unlocked_maps) if profile.map_complete and current_map < 4 else current_map
	selected_level = 1 if profile.map_complete else profile.unlocked
	ui.show_menu(profile,selected_level,last_result,false,selected_map)
	_update_hud()

func _update_hud() -> void:
	if is_instance_valid(ui):
		ui.update_game(score,collected,chain,multiplier(),combo_left,time_left,current_level)
		if is_instance_valid(player): ui.update_actor_feedback(get_canvas_transform()*player.position,60.0*camera.zoom.x,protection_left)

func _start_shake(strength: float, seconds: float) -> void:
	_shake_strength = maxf(_shake_strength,strength)
	_shake_duration = seconds
	_shake_left = seconds
	_shake_clock = 0.0

func _update_shake(delta: float) -> void:
	_shake_left = maxf(0.0,_shake_left-delta)
	_shake_clock += delta
	if _shake_left == 0.0:
		_reset_shake()
		return
	camera.offset = Vector2(sin(_shake_clock*83.0),cos(_shake_clock*97.0))*_shake_strength*(_shake_left/_shake_duration)/camera.zoom.x

func _reset_shake() -> void:
	_shake_left = 0.0
	_shake_strength = 0.0
	if is_instance_valid(camera): camera.offset = Vector2.ZERO

func _on_storage_status_changed() -> void:
	if is_instance_valid(ui): ui.update_storage_status(profile)
