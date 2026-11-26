extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 root.size = Vector2i(960,540)
 var game = load("res://scenes/arcade/game.tscn").instantiate()
 game.profile = ArcadeProfile.new()
 game.profile.save_path = "user://title-screen-test.json"
 game.profile.free_selection = true
 game.profile.powerup_tutorials = [true,true,true]
 root.add_child(game)
 for i in range(8): await process_frame
 expect(game.ui.title_screen.visible,"Title is shown first")
 expect(not game.running and not game.transitioning,"Title does not start a round")
 expect(not game.ui.hud_root.visible,"Title hides HUD")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("C:/Users/65567/Documents/Codex/2026-11-12/https-github-com-sd5913-deepsleep-dont/outputs/Start_Screen_Preview.png")
 game.ui.title_start_button.pressed.emit()
 await process_frame
 expect(not game.ui.title_screen.visible and game.ui.overlay.visible,"Start opens selection")
 expect(not game.running and not game.transitioning,"Selecting a level is still required")
 expect(game.ui.room_buttons.size()==4 and game.ui.map_buttons.size()==4,"Four maps and four rooms remain available")
 game.begin_round(1,1)
 expect(game.running and not game.ui.title_screen.visible,"Round starts after selection")
 game.toggle_pause()
 expect(game.ui.overlay.visible and not game.ui.title_screen.visible,"Pause is independent of title")
 game.toggle_pause()
 game.finish_round()
 expect(game.ui.overlay.visible and not game.ui.title_screen.visible,"Settlement returns to selection")
 game.ui.show_title()
 game.ui.language = "en"
 game.ui.show_title()
 await process_frame
 expect(game.ui.title_start_button.text == "START GAME","English title")
 game.queue_free()
 await process_frame
 if failures == 0: print("PASS: title-first startup, start-to-selection, maps/rooms, direct round start, pause/result, language")
 quit(1 if failures else 0)
