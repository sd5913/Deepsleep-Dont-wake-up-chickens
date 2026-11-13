extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func tick(frames: int) -> void:
	for frame in range(frames):
		await physics_frame

func run() -> void:
	var game = load("res://game.tscn").instantiate()
	game.show_start_menu = false
	game.use_fixed_seed = true
	game.fixed_seed = 7
	root.add_child(game)
	for frame in range(600):
		await physics_frame
		if game.layout_ready: break
	if not game.layout_ready:
		push_error("Playable map must prepare")
		quit(1)
		return
	var player = game.get_node("Player")
	var hen = game.get_node("Chickens/WestHen")
	for other in game.get_node("Chickens").get_children():
		other.set_physics_process(false)
	hen.patrol_points.clear()
	hen.position = Vector2(100, 210)
	hen._facing = Vector2.RIGHT
	player.position = Vector2(160, 210)
	hen.set_physics_process(true)
	await tick(3)
	expect(hen.sees_player and game._alert.level > 0.0, "First sight must immediately alarm")
	# Cover must block both vision and search sounds.
	hen.position = Vector2(260, 285)
	hen._facing = Vector2.DOWN
	player.position = Vector2(260, 425)
	await tick(60)
	expect(not hen.sees_player, "Cover must prevent visual detection")
	expect(not hen.hear_search_noise(player.global_position), "Cover should block search sounds")

	hen.position = Vector2(100, 210)
	hen._facing = Vector2.RIGHT
	player.position = Vector2(160, 210)
	await tick(80)
	expect(hen.sees_player and game._alert.level > 0.0, "Visible player must continue raising alert")
	player.position = Vector2(100, 430)
	await tick(420)
	expect(is_zero_approx(game._alert.level), "Hiding should eventually calm global alert")
	var alert_before: float = game._alert.level
	expect(hen.hear_search_noise(Vector2(100, 250)), "Unblocked nearby search sound must immediately alarm")
	game._update_alert(1.0 / 60.0, false)
	expect(game._alert.level > alert_before, "Sound alarm must raise global alert immediately")
	expect(not hen.take_alarm(), "Sound alarm must be consumed only once")
	expect(not hen.hear_search_noise(Vector2(100, 250)), "Alarm cooldown must prevent repeated sound spikes")
	await tick(300)
	# Feed must give a useful window even while the player is standing nearby.
	var feed = game.get_node("Feed")
	expect(feed.held_count == 2, "Start with two feed charges")
	player.position = Vector2(100, 260)
	var result = feed.throw_from(player, hen.position)
	expect(result == CoopFeedField.ThrowResult.PLACED, "Reachable feed must be placed")
	await tick(3)
	player.position = Vector2(160, 210)
	await tick(180)
	expect(hen._eat_left > 2.0, "Feed should distract a hen for substantially longer than one search")
	expect(not hen.sees_player and not hen.hear_search_noise(player.position), "Eating should suppress alarms and hearing")
	expect(is_zero_approx(game._alert.level), "Eating hen should not raise alert")
	await tick(220)
	expect(is_zero_approx(hen._eat_left), "Hen must finish eating and recover")
	player.position = Vector2(260, 425)
	var before: int = feed.held_count
	result = feed.throw_from(player, Vector2(260, 285))
	expect(result == CoopFeedField.ThrowResult.BLOCKED and feed.held_count == before, "Blocked throws must not consume feed")
	game._aiming_feed = true
	game._feed_aim.update_preview(player.position, player.position + Vector2(30, 0), true)
	game._toggle_pause()
	expect(not game._aiming_feed and not game._feed_aim.visible, "Pause must cancel aiming")
	game._toggle_pause()
	expect(feed.held_count == before, "Canceling aim must not consume feed")
	# The reward budget must force at least one richer nest, while remaining winnable.
	var safe_capacity := 0
	var total_stock := 0
	for nest in game.get_node("Nests").get_children():
		total_stock += nest.eggs_left
		expect(nest.eggs_left >= nest.minimum_stock() and nest.eggs_left <= nest.maximum_stock(), "Nest stock must match its advertised range")
		if not nest.risky: safe_capacity += nest.maximum_stock()
	expect(safe_capacity < game.egg_goal and total_stock >= game.egg_goal, "Round must reward taking a risk without generating an impossible goal")
	# Exercise actual held-input search timing, not just exported multipliers.
	for other in game.get_node("Chickens").get_children():
		other.set_physics_process(false)
		other.sees_player = false
		other.hearing_distance = 0.0
	var safe = game.get_node("Nests/Nest5")
	player.position = safe.position + Vector2(0, 10)
	await tick(3)
	var eggs_before: int = game._eggs
	Input.action_press("interact")
	await tick(82)
	expect(game._eggs == eggs_before + 1, "Small nest should yield an egg in about 1.3 seconds")
	Input.action_release("interact")
	await tick(2)
	player.position = game.get_node("Nests/Nest2").position + Vector2(0, 15)
	await tick(2)
	eggs_before = game._eggs
	Input.action_press("interact")
	await tick(82)
	expect(game._eggs == eggs_before, "Rich nest must expose the player longer")
	await tick(55)
	expect(game._eggs == eggs_before + 1, "Rich search should complete after about 2.2 seconds")
	Input.action_release("interact")
	game._eggs = game.egg_goal
	player.position = game.get_node("Exit").position
	await tick(3)
	Input.action_press("interact")
	await tick(2)
	expect(game._finished and game._hud._result.visible, "Enough eggs plus interaction at the exit should win")
	Input.action_release("interact")
	game.get_node("Audio").stop_all()
	OS.delay_msec(200)
	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: immediate sight/sound alarms, cooldown, cover, calming, six-second feed, blocked throws, pause cancellation, reward budget, timed searches and extraction")
	quit(1 if _failures > 0 else 0)
