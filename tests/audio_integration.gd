extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 var game = load("res://scenes/arcade/game.tscn").instantiate()
 game.profile = ArcadeProfile.new()
 game.profile.save_path = "user://audio-integration-test.json"
 game.profile.powerup_tutorials = [true,true,true]
 root.add_child(game)
 await process_frame
 check(game.audio.CUES.size() == 49,"All effects load")
 for i in range(1,5):
  game.selected_map = i
  game.begin_round(1,i)
  check(game.audio.music.stream == game.audio.TRACKS[i-1],"Map selects correct music")
  check(game.audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Music loops")
  game.abandon_round()
 game.begin_round(2,1)
 var drop = game.powerups.spawn_at(0,game.player.position)
 game.powerups.take(drop)
 check(game.audio.cooldowns.has("17_badge_activate"),"Badge activation audible")
 drop = game.powerups.spawn_at(0,game.player.position)
 game.powerups.take(drop)
 check(game.audio.cooldowns.has("20_powerup_refresh"),"Refresh uses distinct cue")
 game.powerups.advance(6.1)
 check(game.audio.cooldowns.has("21_badge_end"),"Expiry cue")
 game._award(game.player.position,false)
 game._award(game.player.position,false)
 await process_frame
 check(game.audio.cooldowns.has("02_pickup_batch"),"Same-frame pickups aggregate")
 game.toggle_pause()
 check(paused and game.audio.cooldowns.has("28_pause"),"Pause UI sound while world pauses")
 game.toggle_pause()
 game.finish_round(true)
 check(game.audio.cooldowns.has("16_caught_end"),"Caught outcome distinct")
 game.queue_free()
 await process_frame
 DirAccess.remove_absolute("user://audio-integration-test.json")
 if failures == 0: print("PASS: 49 cues, four looped map tracks, powerup activation/refresh/expiry, batched rewards, pause and caught outcome")
 quit(1 if failures else 0)
