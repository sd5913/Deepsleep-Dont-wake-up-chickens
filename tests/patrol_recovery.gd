extends SceneTree

var failures := 0
const SAVE := "user://patrol-recovery-regression.json"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: ArcadeGame = load("res://scenes/arcade/game.tscn").instantiate()
	game.profile = ArcadeProfile.new()
	game.profile.powerup_tutorials = [true,true,true]
	game.profile.save_path = SAVE
	game.guards_enabled = false
	game.use_fixed_seed = true
	game.round_seconds = 300
	root.add_child(game)
	var recoveries := 0
	# First two seeds reproduce the old golden-sheep and ordinary-animal jitter.
	for scenario in [{"map":2,"room":3,"seed":7},{"map":2,"room":4,"seed":17},{"map":3,"room":4,"seed":43},{"map":4,"room":4,"seed":23},{"map":1,"room":4,"seed":31}]:
		game.fixed_seed = scenario.seed
		game.begin_round(scenario.room,scenario.map)
		for i in range(4): await physics_frame
		game._add_hen(true)
		game._add_hen(true)
		var positions: Array[Vector2] = []
		var still: Array[int] = []
		for hen in game.hens:
			positions.append(hen.position)
			still.append(0)
		for window in range(20):
			for i in range(60): await physics_frame
			for j in range(game.hens.size()):
				var hen: ArcadeHen = game.hens[j]
				still[j] = still[j]+1 if hen.position.distance_to(positions[j]) < 4 else 0
				if still[j] == 3:
					failures += 1
					push_error("Animal %d (gold %s) stalled for 3 seconds: %s" % [j,hen.golden,scenario])
				positions[j] = hen.position
		for hen in game.hens: recoveries += hen.recovery_count
		game.abandon_round()
	if recoveries == 0:
		failures += 1
		push_error("Regression seeds must exercise corner recovery, not only empty-floor walking")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	if failures == 0: print("PASS: ordinary and golden patrols recover from corner jitter across all four themes; recoveries ",recoveries)
	quit(1 if failures else 0)
