class_name ArcadeUI
extends CanvasLayer

signal audio_confirm
signal start_requested(level: int, map_index: int)
signal map_selection_changed(map_index: int)
signal restart_requested(map_index: int)
signal upgrade_requested(index: int)
signal pause_requested
signal abandon_requested
signal selection_changed(level: int)
signal powerup_guide_closed

const FONT := preload("res://assets/fonts/CoopUI.ttf")
const PIXEL := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const STAGE_ZH := ["小鸡舍", "鸡舍院落", "扩建农场", "大型农场"]
const STAGE_EN := ["Coop", "Yard", "Farm", "Estate"]
var language := "zh"
var screen: Control
var hud_root: Control
var hud_chrome: Control
var toast_panel: Panel
var item_title: Label
var item_icon: ArcadeUIIcon
var score_title: Label
var clock_title: Label
var powerup_gauges: Array[ProgressBar] = []
var _last_score := 0
var _score_pop := 1.0
var _seconds_left := 60.0
var _current_items := 0
var overlay: ColorRect
var score_label: Label
var egg_label: Label
var time_label: Label
var combo_label: Label
var stage_label: Label
var hint: Label
var toast: Label
var combo_bar: ProgressBar
var combo_anchor: Control
var combo_cheer: Label
var protection_label: Label
var reaction_label: Label
var reaction_marker: Label
var _reaction_left := 0.0
var _reaction_age := 0.0
var danger_label: Label
var _qte_feedback_left := 0.0
var _qte_feedback_result := 0
var storage_notice: Panel
var storage_label: Label
var menu_storage_label: Label
var menu_save_help: Label
var pause_button: Button
var round_duration := 60
var _toast_left := 0.0
var _profile: ArcadeProfile
var _selected := 1
var _map_selected := 1
var primary_button: Button
var map_buttons: Array[Button] = []
var room_buttons: Array[Button] = []
var upgrade_buttons: Array[Button] = []
var transition_screen: ColorRect
var transition_thief: CoopCharacterArt
var _result := {}
var _paused := false
var _running := false
var _current_chain := 0
var _current_multiplier := 1
var _combo_pop_age := 99.0
var _cheer_text := ""
var powerup_guide: ColorRect
var powerup_guide_button: Button
var powerup_bar: Control
var powerup_tiles: Array[Panel] = []
var powerup_timers: Array[Label] = []
var powerup_caption: Label
var _powerup_caption_left := 0.0

func tr2(zh: String, en: String) -> String:
	return en if language == "en" else zh

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	screen.theme = theme
	add_child(screen)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(hud_root)
	hud_chrome = Control.new()
	hud_chrome.set_script(preload("res://scenes/arcade/ui_chrome.gd"))
	hud_root.add_child(hud_chrome)
	_icon(hud_root,Rect2(106,22,32,32),ArcadeUIIcon.Kind.STAR)
	score_title = _left_label(hud_root,Rect2(145,15,130,16),tr2("本局得分","SCORE"),11,ArcadeUISkin.MUTED)
	score_label = _left_label(hud_root,Rect2(145,31,130,26),"0",21)
	score_label.add_theme_font_override("font",PIXEL)
	score_label.pivot_offset = Vector2(0,13)
	danger_label = _label(hud_root,Rect2(310,15,340,22),"",12)
	_icon(hud_root,Rect2(806,22,32,32),ArcadeUIIcon.Kind.CLOCK)
	clock_title = _left_label(hud_root,Rect2(843,15,98,16),tr2("剩余时间","TIME LEFT"),10,ArcadeUISkin.MUTED)
	time_label = _left_label(hud_root,Rect2(843,32,98,25),"1:00",18)
	time_label.add_theme_font_override("font",PIXEL)
	combo_anchor = Control.new()
	combo_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(combo_anchor)
	combo_anchor.draw.connect(_draw_combo_sparkles)
	combo_label = _label(combo_anchor,Rect2(-100,-25,200,30),"",22)
	combo_label.pivot_offset = Vector2(100,15)
	combo_label.add_theme_color_override("font_outline_color",Color("172033"))
	combo_label.add_theme_constant_override("outline_size",5)
	combo_cheer = _label(combo_anchor,Rect2(-100,12,200,24),"",14)
	combo_cheer.add_theme_color_override("font_outline_color",Color("172033"))
	combo_cheer.add_theme_constant_override("outline_size",4)
	protection_label = _label(hud_root,Rect2(0,0,150,25),"",14)
	protection_label.add_theme_color_override("font_color",Color("b8f2ff"))
	protection_label.add_theme_color_override("font_outline_color",Color("172033"))
	protection_label.add_theme_constant_override("outline_size",4)
	protection_label.hide()
	reaction_label = _label(hud_root,Rect2(0,0,280,40),"",24)
	reaction_label.pivot_offset = Vector2(140,20)
	reaction_label.add_theme_color_override("font_color",Color("ffbc6e"))
	reaction_label.add_theme_color_override("font_outline_color",Color("341f2c"))
	reaction_label.add_theme_constant_override("outline_size",6)
	reaction_label.hide()
	reaction_marker = _label(hud_root,Rect2(0,0,48,56),"!",42)
	reaction_marker.add_theme_font_override("font",PIXEL)
	reaction_marker.add_theme_color_override("font_color",Color("fff2a6"))
	reaction_marker.add_theme_color_override("font_outline_color",Color("412330"))
	reaction_marker.add_theme_constant_override("outline_size",6)
	reaction_marker.hide()
	item_icon = _icon(hud_root,Rect2(22,495,30,30),ArcadeUIIcon.Kind.RESOURCE)
	item_title = _left_label(hud_root,Rect2(59,489,110,16),"",10,ArcadeUISkin.MUTED)
	egg_label = _left_label(hud_root,Rect2(59,505,110,22),"0",17)
	stage_label = _label(hud_root,Rect2(786,493,154,30),"",14)
	hint = _label(hud_root,Rect2(217,498,526,27),"",12)
	combo_bar = ProgressBar.new()
	combo_bar.position = Vector2(-45,7)
	combo_bar.size = Vector2(90,4)
	combo_bar.max_value = 2.2
	combo_bar.show_percentage = false
	combo_bar.add_theme_font_size_override("font_size",1)
	combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_bar.add_theme_stylebox_override("fill",_style(Color("efba55"),Color("efba55"),0))
	combo_bar.add_theme_stylebox_override("background",_style(Color("0c1326"),Color("453520"),0))
	combo_anchor.add_child(combo_bar)
	combo_bar.size = Vector2(90,4)
	toast_panel = _panel(hud_root,Rect2(190,70,580,48),ArcadeUISkin.PANEL,ArcadeUISkin.GOLD)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast = _label(toast_panel,Rect2(12,4,556,40),"",14)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_button = _button(hud_root,Rect2(14,12,72,48),"ESC",func(): pause_requested.emit())
	pause_button.add_theme_stylebox_override("normal",ArcadeUISkin.box(ArcadeUISkin.PANEL,ArcadeUISkin.GOLD,2))
	pause_button.add_theme_stylebox_override("hover",ArcadeUISkin.box(Color("1b3043"),ArcadeUISkin.GOLD,2))
	pause_button.add_theme_stylebox_override("pressed",ArcadeUISkin.box(Color("0b1726"),Color("c99a56"),2))
	pause_button.add_theme_stylebox_override("disabled",ArcadeUISkin.box(Color("101e30"),Color("49515a"),2))
	pause_button.add_theme_color_override("font_color",ArcadeUISkin.CREAM)
	pause_button.add_theme_color_override("font_hover_color",ArcadeUISkin.CREAM)
	pause_button.add_theme_color_override("font_pressed_color",ArcadeUISkin.CREAM)
	overlay = ColorRect.new()
	overlay.color = Color(0.015,0.025,0.055,0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(overlay)
	storage_notice = Panel.new()
	storage_notice.position = Vector2(210,96)
	storage_notice.size = Vector2(540,44)
	storage_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storage_notice.add_theme_stylebox_override("panel",_style(ArcadeUISkin.PANEL,ArcadeUISkin.GOLD,1))
	screen.add_child(storage_notice)
	storage_label = _label(storage_notice,Rect2(8,3,524,38),"",13)
	storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storage_label.add_theme_color_override("font_color",Color("ffe1a0"))
	storage_notice.hide()
	_build_powerup_feedback()

func _powerup_icon(parent: Node, kind: int, rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ArcadePowerup.texture_for(kind)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = rect.position
	icon.size = rect.size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _build_powerup_feedback() -> void:
	powerup_bar = Control.new()
	powerup_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(powerup_bar)
	for i in range(3):
		var tile := Panel.new()
		tile.size = Vector2(60,33)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel",_style(Color(0.04,0.08,0.15,0.92),ArcadePowerup.COLORS[i]))
		powerup_bar.add_child(tile)
		_powerup_icon(tile,i,Rect2(2,3,28,26))
		powerup_timers.append(_label(tile,Rect2(32,3,25,23),"",12))
		var gauge := ProgressBar.new()
		gauge.position = Vector2(4,27)
		gauge.size = Vector2(52,3)
		gauge.max_value = ArcadePowerup.DURATIONS[i]
		gauge.show_percentage = false
		gauge.add_theme_font_size_override("font_size",1)
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.add_theme_stylebox_override("fill",ArcadeUISkin.meter(ArcadePowerup.COLORS[i]))
		gauge.add_theme_stylebox_override("background",ArcadeUISkin.meter(Color("263745")))
		tile.add_child(gauge)
		gauge.size = Vector2(52,3)
		powerup_gauges.append(gauge)
		powerup_tiles.append(tile)
	powerup_bar.hide()
	powerup_caption = _label(screen,Rect2(0,0,300,24),"",14)
	powerup_caption.add_theme_color_override("font_outline_color",Color("172033"))
	powerup_caption.add_theme_constant_override("outline_size",4)
	powerup_caption.hide()

func update_powerups(times: Array[float], playing: bool) -> void:
	var shown := 0
	for i in range(3):
		powerup_tiles[i].visible = times[i] > 0.0
		if times[i] <= 0.0: continue
		powerup_tiles[i].position = Vector2(shown*66,0)
		powerup_tiles[i].modulate.a = 1.0 if times[i] > 1.0 else 0.5+0.5*absf(sin(times[i]*15.0))
		powerup_timers[i].text = "%ds" % ceili(times[i])
		powerup_gauges[i].value = times[i]
		shown += 1
	powerup_bar.size = Vector2(maxi(0,shown*66-6),33)
	powerup_bar.visible = shown > 0 and playing and not overlay.visible and not is_powerup_guide_visible()
	powerup_caption.visible = _powerup_caption_left > 0.0 and playing and not overlay.visible and not is_powerup_guide_visible()

func show_powerup_pickup(kind: int) -> void:
	powerup_caption.text = "%s · %ds" % [ArcadePowerup.name_for(kind,language),int(ArcadePowerup.DURATIONS[kind])]
	powerup_caption.add_theme_color_override("font_color",ArcadePowerup.COLORS[kind])
	_powerup_caption_left = 1.3

func is_powerup_guide_visible() -> bool:
	return is_instance_valid(powerup_guide) and powerup_guide.visible

func show_powerup_guide(kind: int) -> void:
	if is_instance_valid(powerup_guide):
		screen.remove_child(powerup_guide)
		powerup_guide.queue_free()
	powerup_guide = ColorRect.new()
	powerup_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	powerup_guide.color = Color(0.015,0.025,0.055,0.82)
	powerup_guide.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(powerup_guide)
	var panel := Panel.new()
	panel.position = Vector2(200,92)
	panel.size = Vector2(560,356)
	panel.add_theme_stylebox_override("panel",_style(Color("0b1728"),ArcadePowerup.COLORS[kind],3))
	powerup_guide.add_child(panel)
	_label(panel,Rect2(20,12,520,30),tr2("发现新道具！","NEW POWERUP!"),20)
	var icon_well := _panel(panel,Rect2(220,48,120,106),Color("203735"),Color("5b7467"))
	_powerup_icon(icon_well,kind,Rect2(8,5,104,96))
	var duration := _panel(panel,Rect2(355,84,74,31),Color("273933"),ArcadePowerup.COLORS[kind])
	_label(duration,Rect2(0,0,74,31),tr2("%d秒","%ds") % int(ArcadePowerup.DURATIONS[kind]),17)
	_label(panel,Rect2(20,158,520,34),ArcadePowerup.name_for(kind,language),26)
	var description := _label(panel,Rect2(30,199,500,46),ArcadePowerup.description_for(kind,language),17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var extra := tr2("这是隐匿，不会挡住小蛇；已有警戒仍会保留。","Stealth does not block snakes or erase existing alert.") if kind == ArcadePowerup.Kind.STEALTH else tr2("同种刷新时间，不同道具可以一起生效。","Same kind refreshes its timer; different kinds combine.")
	_label(panel,Rect2(20,246,520,22),extra,12)
	_label(panel,Rect2(20,273,520,22),tr2("碰到道具自动生效 · 倒计时已暂停","Touch to activate automatically · Timer paused"),14)
	powerup_guide_button = _button(panel,Rect2(142,308,276,48),tr2("知道了，试试看！","GOT IT · LET'S TRY!"),func(): powerup_guide_closed.emit())
	powerup_guide_button.add_theme_stylebox_override("normal",ArcadeUISkin.button("selected"))
	powerup_guide_button.grab_focus()
	powerup_bar.hide()
	powerup_caption.hide()
	pause_button.hide()
	_powerup_caption_left = 0.0

func hide_powerup_guide() -> void:
	if is_instance_valid(powerup_guide): powerup_guide.hide()
	if not overlay.visible: pause_button.show()

func _style(background: Color, border := Color("bd914b"), width := 1) -> StyleBoxFlat:
	return ArcadeUISkin.box(background,border,width)

func _panel(parent: Node, rect: Rect2, background := ArcadeUISkin.PANEL, border := Color("46515b")) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",_style(background,border))
	parent.add_child(panel)
	return panel

func _left_label(parent: Node, rect: Rect2, text: String, font_size := 16, color := ArcadeUISkin.CREAM) -> Label:
	var label := _label(parent,rect,text,font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color",color)
	return label

func _icon(parent: Node, rect: Rect2, kind: int, map_index := 0) -> ArcadeUIIcon:
	var icon := ArcadeUIIcon.new()
	icon.position = rect.position
	icon.size = rect.size
	icon.kind = kind
	icon.theme_index = map_index
	parent.add_child(icon)
	return icon

func _stat_card(parent: Node, rect: Rect2, caption: String, value: String, kind: int, accent: Color) -> void:
	var card := _panel(parent,rect,ArcadeUISkin.CARD,Color(accent,0.45))
	if not _paused: card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_icon(card,Rect2(10,17,32,32),kind,_map_selected-1)
	_left_label(card,Rect2(51,8,rect.size.x-58,18),caption,11,ArcadeUISkin.MUTED)
	var number := _left_label(card,Rect2(51,28,rect.size.x-58,28),value,21,accent)
	if value.length() < 7: number.add_theme_font_override("font",PIXEL)
	if value.length() < 7: number.add_theme_font_size_override("font_size",18)

func _label(parent: Node, rect: Rect2, text: String, font_size := 16) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("ffe5ad"))
	parent.add_child(label)
	return label

func _button(parent: Node, rect: Rect2, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_stylebox_override("normal",ArcadeUISkin.button())
	button.add_theme_stylebox_override("hover",ArcadeUISkin.button("hover"))
	button.add_theme_stylebox_override("pressed",ArcadeUISkin.button("pressed"))
	button.add_theme_stylebox_override("disabled",ArcadeUISkin.button("disabled"))
	button.add_theme_stylebox_override("focus",ArcadeUISkin.focus())
	button.add_theme_font_size_override("font_size",14)
	button.add_theme_color_override("font_color",Color("56331d"))
	button.add_theme_color_override("font_focus_color",Color("56331d"))
	button.add_theme_color_override("font_hover_color",Color("3e2418"))
	button.add_theme_color_override("font_hover_pressed_color",Color("56331d"))
	button.add_theme_color_override("font_pressed_color",Color("56331d"))
	button.add_theme_color_override("font_disabled_color",Color("756c5a"))
	button.pressed.connect(func(): audio_confirm.emit())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	if is_instance_valid(transition_screen) and transition_screen.visible and is_instance_valid(transition_thief):
		transition_thief.update_pose(Vector2.RIGHT,true,&"idle",delta)
	storage_notice.visible = _profile != null and (not _profile.storage_issue.is_empty() or not _profile.saved) and not overlay.visible and not (is_instance_valid(transition_screen) and transition_screen.visible)
	toast_panel.position.y = 146 if storage_notice.visible else 70
	_toast_left = maxf(0.0,_toast_left-delta)
	toast_panel.visible = _toast_left > 0.0 and not overlay.visible and not is_powerup_guide_visible()
	if not get_tree().paused: _qte_feedback_left = maxf(0.0,_qte_feedback_left-delta)
	toast.visible = toast_panel.visible
	if not get_tree().paused:
		_combo_pop_age += delta
		_powerup_caption_left = maxf(0.0,_powerup_caption_left-delta)
		_reaction_left = maxf(0.0,_reaction_left-delta)
		_reaction_age += delta
		_score_pop += delta
	score_label.scale = Vector2.ONE*(1.0+0.10*exp(-_score_pop*12.0))
	reaction_label.visible = _reaction_left > 0.0 and not overlay.visible
	reaction_marker.visible = reaction_label.visible
	reaction_label.scale = Vector2.ONE*(1.0+0.35*exp(-_reaction_age*9.0))
	combo_anchor.visible = _current_chain >= 2 and not overlay.visible and _reaction_left == 0.0 and not is_powerup_guide_visible()
	if overlay.visible: protection_label.hide()
	var pop := _combo_pop_age
	var factor := lerpf(0.65,1.25,pop/0.08) if pop < 0.08 else 1.0+0.25*exp(-12.0*(pop-0.08))*cos((pop-0.08)*18.0)
	combo_label.scale = Vector2.ONE*factor
	combo_label.add_theme_color_override("font_color",Color("fff2ac") if pop < 0.8 else Color("ffe5ad"))
	combo_cheer.text = _cheer_text if pop < 0.85 else (tr2("得分 ×%d","Score ×%d") % _current_multiplier if _current_multiplier > 1 else "")
	combo_anchor.queue_redraw()

func _draw_combo_sparkles() -> void:
	if _combo_pop_age > 0.55: return
	var age := _combo_pop_age
	var color := Color(1.0,0.88,0.44,1.0-age/0.55)
	for i in range(8):
		var direction := Vector2.from_angle(i*TAU/8.0)
		var point := Vector2(direction.x*(72+age*32),direction.y*(25+age*16)-10)
		combo_anchor.draw_line(point,point+direction*5,color,2)

func update_actor_feedback(point: Vector2, body_height: float, protection_left: float) -> void:
	var caption_y := point.y-body_height-42
	if caption_y < 100: caption_y = point.y+42
	combo_anchor.position = Vector2(clampf(point.x,125,835),clampf(caption_y,100,440))
	reaction_label.position = Vector2(clampf(point.x-140,12,668),clampf(point.y-body_height-96 if point.y-body_height-96 > 95 else point.y+64,95,430))
	reaction_marker.position = Vector2(clampf(point.x-24,15,895),clampf(point.y-body_height-57 if point.y-body_height-96 > 95 else point.y+7,90,440))
	protection_label.position = Vector2(clampf(point.x-75,15,795),clampf(point.y+8,80,467))
	protection_label.text = tr2("开局保护 %ds","Protected %ds") % ceili(protection_left)
	protection_label.visible = protection_left > 0 and not overlay.visible
	powerup_bar.position = Vector2(clampf(point.x-powerup_bar.size.x*0.5,12,948-powerup_bar.size.x),clampf(point.y+31,105,447))
	powerup_caption.position = Vector2(clampf(point.x-150,12,648),clampf(point.y+60,110,472))

func show_reaction(zh: String, en: String, seconds := 1.0) -> void:
	reaction_label.text = tr2(zh,en)
	_reaction_left = seconds
	_reaction_age = 0.0
	reaction_label.show()
	reaction_marker.show()

func update_storage_status(profile: ArcadeProfile) -> void:
	_profile = profile
	var text := ""
	match profile.storage_issue:
		"read": text = tr2("无法读取原存档，当前为临时进度；刷新或关闭后，本次进度可能丢失。","Saved progress could not be read. Playing temporarily; refreshing or closing may lose this session's progress.")
		"invalid": text = tr2("原存档暂时无法加载，不会被覆盖；当前临时进度在刷新或关闭后可能丢失。","The existing save could not be loaded and will not be overwritten. Temporary progress may be lost on refresh or close.")
		"write": text = tr2("当前无法保存新进度；可以继续游戏，但刷新或关闭后，新进度可能丢失。","New progress cannot be saved. You can keep playing, but refreshing or closing may lose new progress.")
	if text.is_empty() and not profile.saved:
		text = tr2("当前无法保存新进度；刷新或关闭后，新进度可能丢失。","New progress cannot be saved and may be lost on refresh or close.")
	storage_label.text = text
	if is_instance_valid(menu_storage_label):
		menu_storage_label.text = text
		menu_storage_label.visible = not text.is_empty()
	if is_instance_valid(menu_save_help): menu_save_help.visible = text.is_empty()

func announce(zh: String, en: String) -> void:
	toast.text = tr2(zh,en)
	_toast_left = 3.0

func update_game(score: int, eggs: int, chain: int, multiplier: int, combo_left: float, seconds: float, level: int) -> void:
	if score > _last_score: _score_pop = 0.0
	_last_score = score
	_seconds_left = seconds
	_current_items = eggs
	score_label.text = str(score)
	score_title.text = tr2("本局得分","SCORE")
	clock_title.text = tr2("剩余时间","TIME LEFT")
	item_title.text = ArcadeThemes.item_for(_map_selected,language)
	if item_icon.theme_index != _map_selected-1:
		item_icon.theme_index = _map_selected-1
		item_icon.material = ThemeSprites.item_material(item_icon.theme_index) if item_icon.theme_index > 0 else null
		item_icon.queue_redraw()
	egg_label.text = str(eggs)
	score_label.add_theme_font_size_override("font_size",16 if score >= 1000000 else 21)
	hud_chrome.seconds = seconds
	hud_chrome.queue_redraw()
	time_label.text = "%d:%02d" % [ceili(seconds)/60,ceili(seconds)%60]
	time_label.add_theme_color_override("font_color",Color("ff9d6e") if seconds > 0 and seconds <= 10 else Color("ffe5ad"))
	if chain > _current_chain and chain >= 5 and chain%5 == 0:
		_combo_pop_age = 0.0
		_cheer_text = tr2("漂亮！","NICE!") if chain < 10 else (tr2("继续冲！","KEEP GOING!") if chain < 20 else tr2("停不下来！","UNSTOPPABLE!"))
	_current_chain = chain
	_current_multiplier = multiplier
	combo_label.text = tr2("连击 ×%d","COMBO ×%d") % chain
	combo_anchor.visible = chain >= 2 and not overlay.visible and _reaction_left == 0.0
	combo_bar.value = combo_left
	stage_label.text = "%s %d-%d" % [ArcadeThemes.name_for(_map_selected,language),_map_selected,level]
	hint.text = tr2("左键收集 / 道具碰到即用　 WASD 移动","Click to collect / Touch powerups   WASD move")

func show_menu(profile: ArcadeProfile, selected: int, result := {}, paused := false, map_index := 0) -> void:
	_profile = profile
	_selected = selected
	_map_selected = profile.active_map if map_index == 0 else map_index
	_result = result
	_paused = paused
	_running = false
	map_buttons.clear()
	room_buttons.clear()
	upgrade_buttons.clear()
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.show()
	hud_root.hide()
	_reaction_left = 0.0
	reaction_label.hide()
	reaction_marker.hide()
	combo_anchor.hide()
	protection_label.hide()
	powerup_bar.hide()
	powerup_caption.hide()
	_powerup_caption_left = 0.0
	pause_button.hide()
	if paused:
		_show_pause_card(profile)
		return
	var menu_art := TextureRect.new()
	menu_art.texture = ArcadeUISkin.MENU_BACKGROUND
	menu_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_art.stretch_mode = TextureRect.STRETCH_SCALE
	menu_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	menu_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(menu_art)
	var accent: Color = ArcadeUISkin.ACCENTS[_map_selected-1]
	var panel := _panel(overlay,Rect2(42,22,876,496),ArcadeUISkin.PANEL,ArcadeUISkin.GOLD)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var sidebar := _panel(panel,Rect2(0,0,210,496),ArcadeUISkin.INK,Color("465254"))
	sidebar.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_left_label(panel,Rect2(18,16,172,34),tr2("夜访农场","NIGHT FARM"),25 if language == "zh" else 20)
	var subtitle := _left_label(panel,Rect2(20,50,155,18),"POCKET HARVEST",9,ArcadeUISkin.GOLD)
	subtitle.add_theme_font_override("font",PIXEL)
	_left_label(panel,Rect2(20,75,168,18),tr2("60秒，把袋子装满！","60 seconds. Fill your bag!"),12,ArcadeUISkin.MUTED)
	var title := _left_label(panel,Rect2(230,12,466,39),tr2("%s · 准备出发","%s · READY") % ArcadeThemes.name_for(_map_selected,language),25 if language == "zh" else 23)
	var summary := tr2("任选小关试玩 · 金币保留，进入新图时增益归零。","Pick any room. Keep coins; purchased buffs reset on map entry.") if profile.free_selection else tr2("完成四个小关，解锁下一张地图。","Clear four rooms to unlock the next map.")
	if result.get("caught",false):
		title.text = tr2("再来一局？","ONE MORE TRY?")
		summary = tr2("本局收获已结算，调整路线再试一次。","Your harvest is settled. Pick a new route and try again.")
	elif result.get("map_complete",false):
		title.text = tr2("地图完成！","MAP COMPLETE!")
		summary = tr2("%s 收获完成，准备下一次夜访。","%s complete. Get ready for another harvest.") % ArcadeThemes.name_for(result.get("map",_map_selected),language)
	elif result.has("score"):
		title.text = tr2("收获满满！","A GOOD HARVEST!")
		summary = tr2("本关完成，买点增益再出发吧。","Room complete. Upgrade your kit before the next run.")
	elif result.get("entered_map",false):
		summary = tr2("金币已带到新地图，可以重新搭配本图增益。","Coins carried over. Choose fresh buffs for this map.")
	_left_label(panel,Rect2(230,52,618,23),summary,12,ArcadeUISkin.MUTED)
	var wallet := _panel(panel,Rect2(708,13,140,39),Color("26352e"),Color("81754f"))
	wallet.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_icon(wallet,Rect2(8,5,28,28),ArcadeUIIcon.Kind.COIN)
	_left_label(wallet,Rect2(42,3,91,14),tr2("持有金币","WALLET"),10,ArcadeUISkin.MUTED)
	_left_label(wallet,Rect2(42,16,91,21),str(profile.coins),17,ArcadeUISkin.CREAM)
	for i in range(4):
		var index := i+1
		var button := _button(panel,Rect2(14,108+i*64,182,60),"",func(): map_selection_changed.emit(index))
		var allowed := profile.can_visit_map(index)
		button.disabled = not allowed
		if index == _map_selected: button.add_theme_stylebox_override("normal",ArcadeUISkin.button("selected"))
		_icon(button,Rect2(10,12,36,36),ArcadeUIIcon.Kind.RESOURCE,i)
		var title_rect := Rect2(54,10,119,21)
		if profile.free_selection: title_rect = Rect2(54,15,119,30)
		_left_label(button,title_rect,ArcadeThemes.name_for(index,language),17,Color("56331d") if allowed else Color("756c5a"))
		if not profile.free_selection:
			var state := tr2("已通关","CLEARED") if profile.cleared[i] else tr2("已解锁","UNLOCKED")
			if not allowed: state = tr2("完成前一地图解锁","CLEAR PREVIOUS MAP")
			_left_label(button,Rect2(54,31,119,13),"%02d  %s" % [index,state],10,Color("62401f") if index == _map_selected else Color("756c5a"))
		map_buttons.append(button)
	var controls := _panel(panel,Rect2(14,376,182,103),Color("132333"),Color("34494e"))
	controls.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_left_label(controls,Rect2(12,7,158,20),tr2("操作小抄","QUICK CONTROLS"),12,ArcadeUISkin.GOLD)
	_left_label(controls,Rect2(12,33,158,19),tr2("WASD / 方向键  移动","WASD / arrows  Move"),11)
	_left_label(controls,Rect2(12,54,158,19),tr2("左键收集 · 碰道具即用","Click items · Touch buffs"),11)
	_left_label(controls,Rect2(12,76,158,18),tr2("ESC 暂停 · 金币永久保留","ESC pause · Keep coins"),10,ArcadeUISkin.MUTED)
	var active_map := _map_selected == profile.active_map
	var room := _selected if profile.free_selection else (profile.unlocked if active_map and not profile.map_complete else 1)
	if result.has("score"):
		_stat_card(panel,Rect2(230,83,198,68),tr2("本局得分","RUN SCORE")+tr2(" · 新纪录"," · NEW BEST") if result.get("record",false) else tr2("本局得分","RUN SCORE"),str(result.score),ArcadeUIIcon.Kind.STAR,accent)
		_stat_card(panel,Rect2(438,83,198,68),tr2("收集数量","COLLECTED"),str(result.get("eggs",0)),ArcadeUIIcon.Kind.RESOURCE,ArcadeUISkin.CREAM)
		_stat_card(panel,Rect2(646,83,198,68),tr2("金币入账","COINS EARNED"),"+%d" % result.get("reward",0),ArcadeUIIcon.Kind.COIN,ArcadeUISkin.GOLD)
	else:
		_stat_card(panel,Rect2(230,83,198,68),tr2("每关时长","ROOM LENGTH"),"%ds" % round_duration,ArcadeUIIcon.Kind.CLOCK,accent)
		_stat_card(panel,Rect2(438,83,198,68),tr2("本关最高分","ROOM BEST"),str(profile.best_for(_map_selected,room)),ArcadeUIIcon.Kind.STAR,ArcadeUISkin.CREAM)
		_stat_card(panel,Rect2(646,83,198,68),tr2("地图最高总分","MAP BEST"),str(profile.map_best[_map_selected-1]),ArcadeUIIcon.Kind.STAR,Color("e7c66c"))
	_left_label(panel,Rect2(230,161,320,18),tr2("选择小关","CHOOSE A ROOM"),12,ArcadeUISkin.MUTED)
	for i in range(4):
		var level := i+1
		var name: String = [tr2("初试","FIRST STEPS"),tr2("加量","MORE TO GATHER"),tr2("丰收","HARVEST"),tr2("挑战","CHALLENGE")][i]
		var button := _button(panel,Rect2(230+i*157,184,145,48),"%d-%d  %s" % [_map_selected,level,name],func(): selection_changed.emit(level))
		button.add_theme_font_size_override("font_size",12 if language == "en" else 14)
		button.disabled = not profile.free_selection and (not active_map or profile.map_complete or level != room)
		if level == room:
			button.add_theme_stylebox_override("normal",ArcadeUISkin.button("selected"))
			button.add_theme_color_override("font_color",Color("56331d"))
			button.add_theme_color_override("font_hover_color",Color("56331d"))
			button.add_theme_color_override("font_hover_pressed_color",Color("56331d"))
			button.add_theme_color_override("font_pressed_color",Color("56331d"))
		room_buttons.append(button)
	_left_label(panel,Rect2(230,236,250,18),tr2("本图增益","YOUR KIT FOR THIS MAP"),12,ArcadeUISkin.MUTED)
	var names := [tr2("拾取范围","Pickup reach"),tr2("额外收获","Bonus yield"),tr2("资源窝补货","Nest refill")]
	var details := [tr2("整圈拾取半径更大","A larger collection ring"),tr2("每级 +10% 双份概率","+10% extra yield / level"),tr2("空窝补货间隔更短","Empty nests refill sooner")]
	for i in range(3):
		var index := i
		var grade: int = profile.upgrades[i] if active_map and not profile.map_complete else 0
		var price := profile.cost(i) if active_map and not profile.map_complete else ArcadeProfile.COSTS[0]
		var card := _panel(panel,Rect2(230+i*208,257,198,112),ArcadeUISkin.CARD,Color("42585b"))
		card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		_icon(card,Rect2(7,7,32,32),[ArcadeUIIcon.Kind.RANGE,ArcadeUIIcon.Kind.YIELD,ArcadeUIIcon.Kind.REFILL][i])
		_left_label(card,Rect2(43,7,113,24),names[i],14)
		_label(card,Rect2(155,9,37,20),"%d/5" % grade,11)
		_left_label(card,Rect2(12,40,180,16),details[i],11,ArcadeUISkin.MUTED)
		var button := _button(card,Rect2(10,58,178,48),tr2("已满级","MAX LEVEL") if price < 0 else tr2("升级  %d 币","UPGRADE  %d") % price,func(): upgrade_requested.emit(index))
		button.add_theme_font_size_override("font_size",12)
		button.disabled = not profile.can_visit_map(_map_selected) or price < 0 or profile.coins < price
		button.tooltip_text = tr2("本图四个小关内有效；进入新地图时重置。","Lasts for this map's four rooms. Resets on map entry.")
		if price > profile.coins: button.tooltip_text = tr2("还差 %d 枚金币","Need %d more coins") % (price-profile.coins)
		upgrade_buttons.append(button)
	_left_label(panel,Rect2(230,371,618,18),tr2("散落道具 · 碰到即用","SCATTERED POWERUPS · TOUCH TO USE"),12,ArcadeUISkin.MUTED)
	var pool := ArcadePowerup.available_for(_map_selected,room)
	for i in range(3):
		var unlocked := pool.has(i)
		var card := _panel(panel,Rect2(230+i*208,391,198,33),Color("132536"),Color("354c53"))
		card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		var icon := _powerup_icon(card,i,Rect2(4,2,32,29))
		icon.modulate.a = 1.0 if unlocked else 0.3
		var caption := ArcadePowerup.name_for(i,language) if unlocked else ArcadePowerup.unlock_caption(i,language)
		var label := _left_label(card,Rect2(43,3,150,27),caption,13,ArcadeUISkin.CREAM if unlocked else ArcadeUISkin.MUTED)
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.tooltip_text = ArcadePowerup.description_for(i,language) if unlocked else "%s · %s" % [ArcadePowerup.name_for(i,language),ArcadePowerup.unlock_caption(i,language)]
	menu_save_help = _left_label(panel,Rect2(230,426,618,18),tr2("金币跨图保留 · 购买增益仅在本图有效","Keep coins across maps · Purchased buffs last for this map"),11,ArcadeUISkin.MUTED)
	menu_storage_label = _left_label(panel,Rect2(230,418,618,29),"",10,Color("ffd38a"))
	menu_storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_storage_status(profile)
	var caption := tr2("出发  %d-%d  ·  %d秒","PLAY  %d-%d  ·  %ds") % [_map_selected,room,round_duration]
	primary_button = _button(panel,Rect2(230,448,390,48),caption,func(): start_requested.emit(room,_map_selected))
	primary_button.add_theme_stylebox_override("normal",ArcadeUISkin.button("primary"))
	_button(panel,Rect2(632,448,92,48),"中文" if language == "en" else "English",func():
		language = "zh" if language == "en" else "en"
		show_menu(_profile,_selected,_result,false,_map_selected))
	var restart := _button(panel,Rect2(736,448,110,48),tr2("重开此图","RESTART MAP"),func(): restart_requested.emit(_map_selected))
	restart.add_theme_font_size_override("font_size",12)
	restart.tooltip_text = tr2("金币保留，本图增益与关卡进度归零。","Keep coins; reset this map's buffs and run progress.")
	restart.disabled = not active_map
	primary_button.grab_focus()

func _show_pause_card(profile: ArcadeProfile) -> void:
	var panel := _panel(overlay,Rect2(254,75,452,390),ArcadeUISkin.PANEL,ArcadeUISkin.GOLD)
	_icon(panel,Rect2(202,20,48,48),ArcadeUIIcon.Kind.PAUSE)
	_label(panel,Rect2(24,75,404,37),tr2("歇一会儿","TAKE A BREATHER"),27)
	_label(panel,Rect2(24,116,404,23),tr2("时间已暂停，收获还在袋子里。","Time is paused. Your harvest is safe."),14)
	_stat_card(panel,Rect2(26,153,195,66),tr2("当前得分","CURRENT SCORE"),str(_last_score),ArcadeUIIcon.Kind.STAR,ArcadeUISkin.GOLD)
	_stat_card(panel,Rect2(231,153,195,66),tr2("剩余时间","TIME LEFT"),"%ds" % ceili(_seconds_left),ArcadeUIIcon.Kind.CLOCK,Color("90c9c1"))
	menu_save_help = _label(panel,Rect2(26,231,400,22),tr2("WASD 移动 · 左键收集 · 碰道具即用","WASD move · Click items · Touch powerups"),12)
	menu_storage_label = _label(panel,Rect2(26,228,400,37),"",10)
	menu_storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_storage_status(profile)
	primary_button = _button(panel,Rect2(26,275,400,48),tr2("继续收获  ·  ESC","KEEP GATHERING  ·  ESC"),func(): pause_requested.emit())
	primary_button.add_theme_stylebox_override("normal",ArcadeUISkin.button("primary"))
	_button(panel,Rect2(26,326,192,48),"中文" if language == "en" else "English",func():
		language = "zh" if language == "en" else "en"
		show_menu(_profile,_selected,{},true,_map_selected))
	_button(panel,Rect2(230,326,196,48),tr2("返回菜单","BACK TO MENU"),func(): abandon_requested.emit()).tooltip_text = tr2("退出当前小关，本局未结算收获不会入账。","Leave this room. Unsettled harvest will not be added to your wallet.")
	primary_button.grab_focus()


func show_transition(map_index: int, level: int) -> void:
	if not is_instance_valid(transition_screen):
		transition_screen = ColorRect.new()
		transition_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		transition_screen.color = Color("0b1224")
		transition_screen.mouse_filter = Control.MOUSE_FILTER_STOP
		screen.add_child(transition_screen)
	for child in transition_screen.get_children():
		transition_screen.remove_child(child)
		child.queue_free()
	transition_screen.show()
	var chapter := _label(transition_screen,Rect2(250,73,460,24),"NIGHT FARM / CHAPTER %02d" % map_index,12)
	chapter.add_theme_font_override("font",PIXEL)
	chapter.add_theme_color_override("font_color",ArcadeUISkin.ACCENTS[map_index-1])
	for i in range(4):
		var card := _panel(transition_screen,Rect2(316+i*86,112,70,6),ArcadeUISkin.ACCENTS[map_index-1] if i < level else Color("293a43"),Color("394c53"))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(transition_screen,Rect2(140,145,680,60),ArcadeThemes.name_for(map_index,language),42)
	_label(transition_screen,Rect2(140,217,680,42),tr2("第 %d-%d 小关","ROOM %d-%d") % [map_index,level],25)
	var snake_room := map_index == 1 and level >= 2
	_label(transition_screen,Rect2(140,277,680,30),tr2("小心！有小蛇出没！","WATCH OUT! LITTLE SNAKES AHEAD!") if snake_room else tr2("提好袋子，准备出发……","Pack your bag. A fresh harvest awaits."),22 if snake_room else 18)
	if snake_room:
		_label(transition_screen,Rect2(100,314,760,25),tr2("捡蛋后先放大、裂开；看到感叹号，快侧移躲开小蛇！","The egg grows and cracks. When ! appears, sidestep the snake!"),14)
		var snake := ArcadeSnake.new()
		snake.preview = true
		snake.position = Vector2(490,415)
		snake.scale = Vector2.ONE*1.8
		transition_screen.add_child(snake)
	_label(transition_screen,Rect2(140,477,680,28),tr2("金币随身带走，增益在本地图内累积","Keep your coins. Build buffs within this map."),15)
	transition_thief = CoopCharacterArt.new()
	transition_thief.character = 0
	transition_thief.sprite_height = 62
	transition_thief.position = Vector2(240,445)
	transition_screen.add_child(transition_thief)
	create_tween().tween_property(transition_thief,"position:x",720.0,0.95)
	transition_screen.modulate.a = 0
	create_tween().tween_property(transition_screen,"modulate:a",1.0,0.18)

func hide_transition() -> void:
	if is_instance_valid(transition_screen): transition_screen.hide()

func hide_menu() -> void:
	overlay.hide()
	hud_root.show()
	_running = true
	pause_button.show()

func update_danger(level: float, seen: bool, farmer_present: bool) -> void:
	var qte_now := _running and level >= 60.0
	if qte_now and not hud_chrome.qte_active: hud_chrome.qte_phase = 0.0
	hud_chrome.qte_active = qte_now
	hud_chrome.danger_value = clampf(level,0,100)
	hud_chrome.farmer_present = farmer_present
	hud_chrome.queue_redraw()
	if _qte_feedback_left > 0.0:
		danger_label.text = tr2("命中！警戒降低","NICE HIT! ALERT DOWN") if _qte_feedback_result == 1 else tr2("没踩中，再等金色区","MISSED · WAIT FOR GOLD")
	elif qte_now:
		danger_label.text = tr2("警戒 %d / 100 · 空格踩金区","ALERT %d / 100 · SPACE ON GOLD") % floori(level)
	else:
		danger_label.text = tr2("农夫追赶中 · 绕到掩体后！","FARMER CHASING · BREAK SIGHT!") if farmer_present else (tr2("被发现！警戒 %d / 100","SPOTTED · ALERT %d / 100") % floori(level) if seen else tr2("警戒 %d / 100","ALERT %d / 100") % floori(level))
	var color := Color("9cc880") if _qte_feedback_left > 0.0 and _qte_feedback_result == 1 else (Color("e5bc70") if qte_now else (Color("ff8b72") if seen or farmer_present else Color("ffe5ad")))
	danger_label.add_theme_color_override("font_color",color)

func try_alert_qte() -> int:
	if not hud_chrome.qte_active: return -1
	var hit: bool = hud_chrome.qte_phase >= 0.62 and hud_chrome.qte_phase <= 0.78
	_qte_feedback_result = 1 if hit else 0
	_qte_feedback_left = 0.75
	return _qte_feedback_result
