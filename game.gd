extends Node2D

const FARMER_SCENE := preload("res://scenes/farmer.tscn")

@export_range(1.0, 600.0, 1.0) var round_seconds := 120.0
@export_range(1, 99, 1) var egg_goal := 8
@export_range(0.1, 10.0, 0.1) var search_seconds := 2.0
@export_range(0.1, 5.0, 0.05) var search_noise_interval := 0.65
@export_range(1.0, 100.0, 1.0) var farmer_alert_threshold := 60.0
@export_range(0.1, 5.0, 0.1) var farmer_warning_seconds := 1.2

@export_group("Round Seed")
@export var use_fixed_seed := false
@export_range(0, 4294967295, 1) var fixed_seed := 0

@export_group("Interface")
@export var show_start_menu := true

static var _restart_without_menu := false

var round_seed: int
var layout_ready := false

var _show_intro := true
var _round_started := false
var _interact_released_during_pause := false
var _time_left := 0.0
var _eggs := 0
var _search_elapsed := 0.0
var _noise_elapsed := 0.0
var _pickup_pressed := false
var _nearby_nest: CoopNest
var _finished := false
var _farmer: CoopFarmer
var _farmer_armed := true
var _farmer_warning_left := 0.0
var _reported_position := Vector2.ZERO
var _aiming_feed := false

@onready var _feed_aim: Node2D = $FeedAim

@onready var _player: CoopPlayer = $Player
@onready var _exit: Area2D = $Exit
@onready var _nests: Array[Node] = $Nests.get_children()
@onready var _chickens: Array[Node] = $Chickens.get_children()
@onready var _alert: CoopAlert = $Alert
@onready var _feed: CoopFeedField = $Feed
@onready var _layout: CoopLayout = $Layout
@onready var _hud: CoopHUD = $HUD
@onready var _audio: CoopRoundAudio = $Audio
@onready var _farmer_entrance: Marker2D = $FarmerEntrance


func _ready() -> void:
	set_physics_process(false)
	_player.set_physics_process(false)
	for chicken: CoopChicken in _chickens:
		chicken.set_physics_process(false)

	_initialize_round_randomness()
	_show_intro = show_start_menu and not _restart_without_menu
	_restart_without_menu = false
	_hud.start_requested.connect(_start_round)
	_hud.pause_requested.connect(_toggle_pause)
	_hud.paused_interact_released.connect(_on_paused_interact_released)
	_hud.restart_requested.connect(_restart)
	if _show_intro:
		_hud.show_start(false)
	_hud.update_interaction("正在准备鸡舍", 0.0, false)
	_layout.prepared.connect(_on_layout_prepared, CONNECT_ONE_SHOT)
	_layout.prepare(round_seed, egg_goal)


func _on_layout_prepared(success: bool) -> void:
	if not success:
		_hud.update_interaction("地图验证失败，请重开", 0.0, false)
		_hud.show_layout_error()
		return

	_time_left = round_seconds
	_hud.update_status(_eggs, egg_goal, ceili(_time_left))
	_hud.update_interaction("靠近鸟巢搜寻鸡蛋", 0.0, false)
	layout_ready = true
	if _show_intro:
		_hud.show_start(true)
	else:
		_start_round()


func _start_round() -> void:
	if not layout_ready or _round_started:
		return
	_round_started = true
	_hud.hide_menu()
	_player.set_physics_process(true)
	for chicken: CoopChicken in _chickens:
		chicken.set_physics_process(true)
	set_physics_process(true)


func _toggle_pause() -> void:
	if not _round_started or _finished:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		_cancel_feed_aim()
		_hud.show_pause()
	else:
		if _interact_released_during_pause:
			_search_elapsed = 0.0
			_noise_elapsed = 0.0
			_pickup_pressed = false
			_interact_released_during_pause = false
		_hud.hide_menu()


func _on_paused_interact_released() -> void:
	_interact_released_during_pause = true


func _initialize_round_randomness() -> void:
	var round_rng := RandomNumberGenerator.new()
	if use_fixed_seed:
		round_seed = fixed_seed
	else:
		round_rng.randomize()
		round_seed = round_rng.randi()
	round_rng.seed = round_seed
	if OS.is_debug_build():
		print("Round seed: %d" % round_seed)

	var stock_rng := RandomNumberGenerator.new()
	stock_rng.seed = round_rng.randi()
	for chicken: CoopChicken in _chickens:
		chicken.set_patrol_seed(round_rng.randi())

	var remaining_capacity := 0
	for nest: CoopNest in _nests:
		remaining_capacity += nest.maximum_stock()
	egg_goal = mini(egg_goal, remaining_capacity)
	var eggs_needed := egg_goal
	for nest: CoopNest in _nests:
		remaining_capacity -= nest.maximum_stock()
		var minimum := maxi(nest.minimum_stock(), eggs_needed - remaining_capacity)
		var stock := stock_rng.randi_range(minimum, nest.maximum_stock())
		nest.set_initial_stock(stock)
		eggs_needed -= stock


func _physics_process(delta: float) -> void:
	_time_left = maxf(_time_left - delta, 0.0)
	if is_zero_approx(_time_left):
		_time_left = 0.0
		_finish(false)
		return

	var at_exit := _exit.overlaps_body(_player)
	if at_exit and _eggs >= egg_goal and Input.is_action_just_pressed("interact"):
		_finish(true)
		return

	var pickup: CoopFeed = null if at_exit else _feed.nearest_pickup(_player.global_position)
	if not Input.is_action_pressed("interact") or Input.is_action_just_released("interact"):
		_pickup_pressed = false
	if pickup != null and Input.is_action_just_pressed("interact") and not _pickup_pressed:
		_feed.collect(pickup)
		_pickup_pressed = true
		pickup = null
		_hud.show_feed_notice("拾取饲料，按 Q 投放")

	_select_nest(null if at_exit or pickup != null else _find_nearest_nest())
	var searching := (
		_nearby_nest != null
		and _nearby_nest.eggs_left > 0
		and not _pickup_pressed
		and Input.is_action_pressed("interact")
	)
	if not searching or Input.is_action_just_released("interact"):
		_search_elapsed = 0.0
		_noise_elapsed = 0.0
	var duration := search_seconds * _nearby_nest.search_multiplier() if _nearby_nest != null else search_seconds
	if searching:
		_search_elapsed += delta
		if _search_elapsed >= duration and _nearby_nest.take_egg():
			_eggs += 1
			_search_elapsed -= duration
			_audio.play_cue(&"Egg")
		if _nearby_nest.eggs_left == 0:
			_search_elapsed = 0.0
			searching = false

	_player.movement_locked = searching
	_player.searching = searching
	_update_feed_aim()
	_hud.update_feed(_feed.held_count, delta)
	_update_alert(delta, searching)
	_update_farmer(delta)
	_hud.update_status(_eggs, egg_goal, ceili(_time_left))
	var hint := "按 E 拾取饲料" if pickup != null else _interaction_hint(at_exit, searching)
	if _aiming_feed:
		hint = "松开 Q 投放，右键取消"
	var missing_eggs := egg_goal - _eggs if at_exit and _eggs < egg_goal else 0
	_hud.update_interaction(hint, _search_elapsed / duration, searching, missing_eggs)


func _find_nearest_nest() -> CoopNest:
	var nearest: CoopNest
	var nearest_distance := INF
	for nest: CoopNest in _nests:
		var distance := nest.global_position.distance_squared_to(_player.global_position)
		if distance <= nest.interaction_radius ** 2 and distance < nearest_distance:
			nearest = nest
			nearest_distance = distance
	return nearest


func _select_nest(nest: CoopNest) -> void:
	if nest == _nearby_nest:
		return
	if _nearby_nest != null:
		_nearby_nest.set_targeted(false)
	_nearby_nest = nest
	_search_elapsed = 0.0
	_noise_elapsed = 0.0
	if _nearby_nest != null:
		_nearby_nest.set_targeted(true)


func _update_alert(delta: float, searching: bool) -> void:
	_noise_elapsed = _noise_elapsed + delta if searching else 0.0
	var noise_pulse := _noise_elapsed >= search_noise_interval
	if noise_pulse:
		_noise_elapsed -= search_noise_interval
		_audio.play_cue(&"Search")

	var seeing_hens := 0
	var clucks := 0
	for chicken: CoopChicken in _chickens:
		if noise_pulse:
			chicken.hear_search_noise(_player.global_position)
		if chicken.sees_player:
			seeing_hens += 1
		if chicken.take_alarm():
			clucks += 1

	if clucks > 0:
		_audio.play_cue(&"Cluck")
	_alert.advance(delta, seeing_hens, clucks, _farmer != null and _farmer.sees_player)
	_hud.update_alert(_alert.level, seeing_hens > 0, clucks > 0, delta)


func _update_feed_aim() -> void:
	if Input.is_action_just_pressed("throw_feed"):
		if _feed.held_count > 0:
			_aiming_feed = true
		else:
			_hud.show_feed_notice("没有饲料可投放")
	if not _aiming_feed:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_cancel_feed_aim()
		return
	var destination := _feed.aim_destination(_player)
	_feed_aim.update_preview(_player.global_position, destination, _feed.can_place(_player, destination))
	if Input.is_action_just_released("throw_feed"):
		_throw_feed()
		_cancel_feed_aim()


func _cancel_feed_aim() -> void:
	_aiming_feed = false
	_feed_aim.hide()


func _throw_feed() -> void:
	match _feed.throw_from(_player):
		CoopFeedField.ThrowResult.PLACED:
			_player.show_feed_toss()
			_hud.show_feed_notice("已投放饲料")
		CoopFeedField.ThrowResult.EMPTY:
			_hud.show_feed_notice("没有饲料可投放")
		CoopFeedField.ThrowResult.BLOCKED:
			_hud.show_feed_notice("前方无法投放饲料")


func _update_farmer(delta: float) -> void:
	if _farmer != null:
		match _farmer.state:
			CoopFarmer.State.CHASING:
				_hud.show_farmer_status("农夫正在追赶")
			CoopFarmer.State.SEARCHING:
				_hud.show_farmer_status("农夫正在搜寻")
			CoopFarmer.State.RETREATING:
				_hud.show_farmer_status("农夫正在撤退")
		return

	if _farmer_warning_left > 0.0:
		_farmer_warning_left = maxf(0.0, _farmer_warning_left - delta)
		if is_zero_approx(_farmer_warning_left):
			_farmer_warning_left = 0.0
			_spawn_farmer()
		return

	if _alert.level < farmer_alert_threshold:
		_farmer_armed = true
	elif _farmer_armed:
		_farmer_armed = false
		_farmer_warning_left = farmer_warning_seconds
		_reported_position = _player.global_position
		_hud.show_farmer_status("农夫即将从北侧入场")


func _spawn_farmer() -> void:
	_farmer = FARMER_SCENE.instantiate()
	_farmer.player = _player
	_farmer.alert = _alert
	_farmer.position = _farmer_entrance.position
	_farmer.home_position = _farmer_entrance.global_position
	_farmer.last_known_position = _reported_position
	_farmer.player_caught.connect(_on_player_caught)
	_farmer.departed.connect(_on_farmer_departed)
	add_child(_farmer)
	_hud.show_farmer_status("农夫正在搜寻")
	_audio.play_cue(&"Farmer")


func _on_player_caught() -> void:
	_finish(false, CoopHUD.Failure.CAUGHT)


func _on_farmer_departed() -> void:
	_farmer.queue_free()
	_farmer = null
	_farmer_armed = _alert.level < farmer_alert_threshold
	_hud.show_farmer_status("")


func _interaction_hint(at_exit: bool, searching: bool) -> String:
	if at_exit:
		if _eggs >= egg_goal:
			return "按 E 撤离"
		return "撤离还差 %d 枚鸡蛋"
	if _nearby_nest != null:
		if _nearby_nest.eggs_left == 0:
			return "已搜空"
		if searching:
			return "搜寻中，松开 E 取消"
		if _nearby_nest.status == CoopNest.Status.SEARCHABLE:
			return "仍可搜寻，按住 E 继续"
		return "高收益鸡窝，按住 E 搜寻" if _nearby_nest.risky else "低收益鸡窝，按住 E 搜寻"
	if _eggs >= egg_goal:
		return "目标达成，返回入口撤离"
	return "靠近鸟巢搜寻鸡蛋"


func _finish(won: bool, failure := CoopHUD.Failure.TIMEOUT) -> void:
	if _finished:
		return
	_finished = true
	_cancel_feed_aim()
	set_physics_process(false)
	_player.movement_locked = true
	_player.searching = false
	_player.velocity = Vector2.ZERO
	for chicken: CoopChicken in _chickens:
		chicken.set_physics_process(false)
	if _farmer != null:
		_farmer.set_physics_process(false)
	_farmer_warning_left = 0.0
	_hud.show_farmer_status("")
	_hud.show_feed_notice("")
	_select_nest(null)
	_hud.update_status(_eggs, egg_goal, ceili(_time_left))
	_hud.update_interaction("", 0.0, false)
	_audio.stop_all()
	_audio.play_cue(&"Success" if won else &"Failure")
	_hud.show_result(won, _eggs, egg_goal, floori(round_seconds - _time_left), failure)


func _restart() -> void:
	_audio.stop_all()
	get_tree().paused = false
	_restart_without_menu = true
	if get_tree().reload_current_scene() != OK:
		_restart_without_menu = false
