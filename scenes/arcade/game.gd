class_name ArcadeGame
extends Node2D

const PLAYER := preload("res://scenes/player.tscn")
const AUDIO := preload("res://scenes/round_audio.tscn")
const CHICKEN := preload("res://scenes/chicken.tscn")
const FARMER := preload("res://scenes/farmer.tscn")
const HEN_SCRIPT := preload("res://scenes/arcade/hen.gd")
const RANGE_SCRIPT := preload("res://scenes/arcade/pickup_range.gd")
const EFFECT := preload("res://scenes/arcade/effect.gd")
@export_range(10.0,300.0,1.0) var round_seconds := 60.0
@export var use_fixed_seed := false
@export var fixed_seed := 7
@export var guards_enabled := true
@export_range(30.0,220.0,5.0) var base_pickup_radius := 70.0
var profile: ArcadeProfile
var selected_level := 1
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
var farmer: CoopFarmer
var pickup_circle: Node2D
var _farmer_warning := 0.0
var _farmer_armed := true
var _reported_position := Vector2.ZERO
var _last_seconds_announced := false
var protection_left := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if profile == null:
		profile = ArcadeProfile.new()
		profile.load_progress()
	selected_level = profile.unlocked
	_rng.randomize()
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	ui = ArcadeUI.new()
	ui.round_duration = ceili(round_seconds)
	add_child(ui)
	ui.start_requested.connect(begin_round)
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
	ui.show_menu(profile,selected_level)
	_update_hud()

func _select_level(level: int) -> void:
	if running or level < 1 or level > profile.unlocked: return
	selected_level = level
	_build_world(level)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level,last_result)
	_update_hud()

func _buy_upgrade(index: int) -> void:
	if running: return
	profile.buy(index)
	ui.show_menu(profile,selected_level,last_result)

func _build_world(level: int) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	eggs.clear()
	nests.clear()
	hens.clear()
	farmer = null
	_farmer_warning = 0.0
	_farmer_armed = true
	protection_left = 0.0
	world = ArcadeWorld.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var seed_value := fixed_seed if use_fixed_seed else _rng.randi()
	world.build(level,seed_value)
	current_level = level
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
	world.add_child(alert)
	for i in range(2 + level*2):
		var point := world.free_point(52,true)
		if point == Vector2.INF: break
		world.nest_points.append(point)
		var nest := ArcadeNest.new()
		nest.position = point
		nest.rng.seed = world.rng.randi()
		nest.refill_speed = pow(0.86,profile.upgrades[2])
		world.add_child(nest)
		nests.append(nest)
	for i in range(3+level): _add_hen(false)
	_spawn_batch(18+level*14)

func begin_round(level: int) -> void:
	if running: return
	if level < 1 or level > profile.unlocked: return
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
	player.invulnerable = protection_left > 0.0
	_update_guards(delta)
	if not running: return
	_update_pickup_feedback(get_global_mouse_position())
	if time_left <= 10.0 and not _last_seconds_announced:
		_last_seconds_announced = true
		ui.announce("最后 10 秒，抓紧捡蛋！","10 seconds left. Keep collecting!")
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
	if current_level >= 3 and golden_count == 0 and elapsed >= round_seconds*0.5:
		_add_hen(true)
		golden_count = 1
		ui.announce("黄金鸡来了！它留下的金蛋价值更高。","Golden hen! Follow the high-value golden eggs.")
	if current_level == 4 and golden_count == 1 and elapsed >= round_seconds*0.75:
		_add_hen(true)
		golden_count = 2
		ui.announce("第二只黄金鸡加入了农场！","A second golden hen has arrived!")
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
		var origin := closest.position
		if not can_collect_point(closest.position):
			ui.announce("只能捡身边的蛋；被木箱挡住时请绕过去。","Move closer; crates can block a pickup.")
			return false
		_collect_egg(closest)
		if profile.upgrades[0] > 0:
			var radius: float = (18 + profile.upgrades[0]*12) / camera.zoom.x
			for other: ArcadeEgg in eggs.duplicate():
				if other.position.distance_squared_to(origin) <= radius*radius and can_collect_point(other.position): _collect_egg(other)
		return true
	if target is ArcadeNest:
		var nest: ArcadeNest = target
		if not can_collect_point(nest.position):
			ui.announce("走近草窝，再左键连续取蛋。","Move closer, then left-click the nest repeatedly.")
			return false
		if nest.take():
			_award(nest.position+Vector2(0,-8),false)
			return true
		ui.announce("这处鸡窝正在补货，先捡地面的蛋吧。","Nest refilling. Pick up some ground eggs meanwhile.")
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
		egg.highlighted = reachable and egg == target
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
	_award(egg.position,egg.golden)
	egg.queue_free()

func _award(point: Vector2, gold: bool) -> void:
	var units := 2 if world.rng.randf() < profile.upgrades[1]*0.1 else 1
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
	effect.z_index = 5
	world.add_child(effect)
	player.show_feed_toss()
	_update_hud()

func multiplier() -> int:
	return 1 + mini(3,chain/12)

func _add_hen(gold: bool) -> void:
	var point := world.patrol_point(hens.size()%4)
	if point == Vector2.INF: point = world.free_point(24,true)
	if point == Vector2.INF: return
	var node = CHICKEN.instantiate()
	node.set_script(HEN_SCRIPT)
	var hen: ArcadeHen = node
	hen.world = world
	hen.player = player
	hen.golden = gold
	hen.position = point
	hen.patrol_speed = 90.0 if gold else 82.0
	hen.waypoint_pause = 0.6
	hen.vision_distance = 175.0
	hen.set_patrol_seed(world.rng.randi())
	world.add_child(hen)
	hens.append(hen)
	hen.egg_laid.connect(_spawn_egg_at)

func pickup_radius() -> float:
	return base_pickup_radius + profile.upgrades[0]*4.0

func can_collect_point(point: Vector2) -> bool:
	if player.position.distance_squared_to(point) > pow(pickup_radius(),2): return false
	if player.position.distance_squared_to(point) < 0.01: return true
	var ray := PhysicsRayQueryParameters2D.create(player.global_position,point,2)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _update_guards(delta: float) -> void:
	if not guards_enabled: return
	if player.invulnerable:
		for hen in hens: hen.take_alarm()
		ui.update_danger(alert.level,false,false)
		return
	var seen := 0
	var clucks := 0
	for hen in hens:
		if hen.sees_player: seen += 1
		if hen.take_alarm(): clucks += 1
	alert.advance(delta,seen,clucks,is_instance_valid(farmer) and farmer.sees_player)
	ui.update_danger(alert.level,seen > 0,is_instance_valid(farmer))
	if is_instance_valid(farmer): return
	if _farmer_warning > 0.0:
		_farmer_warning = maxf(0,_farmer_warning-delta)
		if _farmer_warning == 0.0: _spawn_farmer()
	elif alert.level < 60:
		_farmer_armed = true
	elif _farmer_armed:
		_farmer_armed = false
		_farmer_warning = 1.8
		_reported_position = player.position
		ui.announce("警戒升高，农夫即将从北侧入场！","High alert! The farmer is coming from the north!")

func _spawn_farmer() -> void:
	farmer = FARMER.instantiate()
	farmer.player = player
	farmer.alert = alert
	farmer.position = Vector2(world.bounds.get_center().x,world.bounds.position.y+25)
	farmer.home_position = farmer.position
	farmer.last_known_position = _reported_position
	farmer.player_caught.connect(func(): finish_round(true))
	farmer.departed.connect(_farmer_departed)
	world.add_child(farmer)
	ui.announce("农夫正在搜寻，利用木箱躲开视线！","Farmer searching! Break sight behind crates!")

func _farmer_departed() -> void:
	if is_instance_valid(farmer): farmer.queue_free()
	farmer = null
	_farmer_armed = alert.level < 60

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
		if clear: _spawn_egg_at(point,false)

func _spawn_egg_at(point: Vector2, gold: bool) -> void:
	if not world.is_free(point,12,true): return
	if eggs.size() >= 48+current_level*18:
		if not gold: return
		var replaced := false
		for old in eggs:
			if not old.golden:
				eggs.erase(old)
				old.queue_free()
				replaced = true
				break
		if not replaced: return
	var egg := ArcadeEgg.new()
	egg.position = point
	egg.golden = gold
	egg.phase = world.rng.randf()*TAU
	egg.scale = Vector2.ONE * maxf(1.2,1.05/camera.zoom.x)
	egg.z_index = 1
	world.add_child(egg)
	eggs.append(egg)

func toggle_pause() -> void:
	if not running: return
	get_tree().paused = not get_tree().paused
	_clear_pickup_feedback()
	if get_tree().paused: ui.show_menu(profile,current_level,{},true)
	else: ui.hide_menu()

func abandon_round() -> void:
	_clear_pickup_feedback()
	get_tree().paused = false
	running = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_menu(profile,selected_level)

func finish_round(caught := false) -> void:
	if not running: return
	_clear_pickup_feedback()
	running = false
	get_tree().paused = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	last_result = profile.settle(current_level,score,not caught)
	last_result["eggs"] = collected
	last_result["caught"] = caught
	selected_level = current_level if caught else mini(current_level+1,profile.unlocked)
	ui.show_menu(profile,selected_level,last_result)
	_update_hud()

func _update_hud() -> void:
	if is_instance_valid(ui):
		ui.update_game(score,collected,chain,multiplier(),combo_left,time_left,current_level)
		if is_instance_valid(player): ui.update_actor_feedback(get_canvas_transform()*player.position,60.0*camera.zoom.x,protection_left)
