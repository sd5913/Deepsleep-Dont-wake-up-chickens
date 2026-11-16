class_name ArcadeUI
extends CanvasLayer

signal start_requested(level: int, map_index: int)
signal map_selection_changed(map_index: int)
signal restart_requested(map_index: int)
signal upgrade_requested(index: int)
signal pause_requested
signal abandon_requested
signal selection_changed(level: int)

const FONT := preload("res://assets/fonts/CoopUI.ttf")
const PIXEL := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const STAGE_ZH := ["小鸡舍", "鸡舍院落", "扩建农场", "大型农场"]
const STAGE_EN := ["Coop", "Yard", "Farm", "Estate"]
var language := "zh"
var screen: Control
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
	var frames := Control.new()
	frames.set_script(preload("res://scenes/hud_frames.gd"))
	frames.set("show_combo_frame",false)
	frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(frames)
	danger_label = _label(screen,Rect2(205,10,166,30),"",15)
	score_label = _label(screen,Rect2(47,11,137,31),"",17)
	time_label = _label(screen,Rect2(832,11,106,31),"1:00",18)
	combo_anchor = Control.new()
	combo_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(combo_anchor)
	combo_anchor.draw.connect(_draw_combo_sparkles)
	combo_label = _label(combo_anchor,Rect2(-100,-25,200,30),"",22)
	combo_label.pivot_offset = Vector2(100,15)
	combo_label.add_theme_color_override("font_outline_color",Color("172033"))
	combo_label.add_theme_constant_override("outline_size",5)
	combo_cheer = _label(combo_anchor,Rect2(-100,12,200,24),"",14)
	combo_cheer.add_theme_color_override("font_outline_color",Color("172033"))
	combo_cheer.add_theme_constant_override("outline_size",4)
	protection_label = _label(screen,Rect2(0,0,150,25),"",14)
	protection_label.add_theme_color_override("font_color",Color("b8f2ff"))
	protection_label.add_theme_color_override("font_outline_color",Color("172033"))
	protection_label.add_theme_constant_override("outline_size",4)
	protection_label.hide()
	reaction_label = _label(screen,Rect2(0,0,280,40),"",24)
	reaction_label.pivot_offset = Vector2(140,20)
	reaction_label.add_theme_color_override("font_color",Color("ffbc6e"))
	reaction_label.add_theme_color_override("font_outline_color",Color("341f2c"))
	reaction_label.add_theme_constant_override("outline_size",6)
	reaction_label.hide()
	reaction_marker = _label(screen,Rect2(0,0,48,56),"!",42)
	reaction_marker.add_theme_font_override("font",PIXEL)
	reaction_marker.add_theme_color_override("font_color",Color("fff2a6"))
	reaction_marker.add_theme_color_override("font_outline_color",Color("412330"))
	reaction_marker.add_theme_constant_override("outline_size",6)
	reaction_marker.hide()
	egg_label = _label(screen,Rect2(22,499,140,29),"",15)
	stage_label = _label(screen,Rect2(785,499,154,29),"",14)
	hint = _label(screen,Rect2(231,499,500,29),"",14)
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
	toast = _label(screen,Rect2(200,63,560,30),"",17)
	toast.add_theme_color_override("font_outline_color",Color("172033"))
	toast.add_theme_constant_override("outline_size",4)
	pause_button = _button(screen,Rect2(852,48,91,25),"Esc",func(): pause_requested.emit())
	pause_button.add_theme_font_size_override("font_size",13)
	overlay = ColorRect.new()
	overlay.color = Color(0.015,0.025,0.055,0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(overlay)
	storage_notice = Panel.new()
	storage_notice.position = Vector2(210,96)
	storage_notice.size = Vector2(540,44)
	storage_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storage_notice.add_theme_stylebox_override("panel",_style(Color("172137"),Color("d6ac64"),1))
	screen.add_child(storage_notice)
	storage_label = _label(storage_notice,Rect2(8,3,524,38),"",13)
	storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storage_label.add_theme_color_override("font_color",Color("ffe1a0"))
	storage_notice.hide()

func _style(background: Color, border := Color("bd914b"), width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(width)
	style.border_color = border
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

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
	button.add_theme_stylebox_override("normal",_style(Color("202237")))
	button.add_theme_stylebox_override("hover",_style(Color("594126"),Color("ffe19b"),2))
	button.add_theme_stylebox_override("pressed",_style(Color("7b592d"),Color("ffe19b"),2))
	button.add_theme_stylebox_override("disabled",_style(Color("111725"),Color("343744")))
	button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),Color("fff0b0"),2))
	button.add_theme_font_size_override("font_size",15)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	if is_instance_valid(transition_screen) and transition_screen.visible and is_instance_valid(transition_thief):
		transition_thief.update_pose(Vector2.RIGHT,true,&"idle",delta)
	storage_notice.visible = _profile != null and (not _profile.storage_issue.is_empty() or not _profile.saved) and not overlay.visible and not (is_instance_valid(transition_screen) and transition_screen.visible)
	_toast_left = maxf(0.0,_toast_left-delta)
	toast.visible = _toast_left > 0.0 and not overlay.visible
	if not get_tree().paused:
		_combo_pop_age += delta
		_reaction_left = maxf(0.0,_reaction_left-delta)
		_reaction_age += delta
	reaction_label.visible = _reaction_left > 0.0 and not overlay.visible
	reaction_marker.visible = reaction_label.visible
	reaction_label.scale = Vector2.ONE*(1.0+0.35*exp(-_reaction_age*9.0))
	combo_anchor.visible = _current_chain >= 2 and not overlay.visible and _reaction_left == 0.0
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
	score_label.text = tr2("得分 %d","Score %d") % score
	egg_label.text = "%s %d" % [ArcadeThemes.item_for(_map_selected,language),eggs]
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
	hint.text = tr2("点圈内物品收整圈 / 连点资源点　 WASD 移动","Click an item to gather the ring / patches   WASD move")

func show_menu(profile: ArcadeProfile, selected: int, result := {}, paused := false, map_index := 0) -> void:
	_profile = profile
	_selected = selected
	_map_selected = profile.active_map if map_index == 0 else map_index
	_result = result
	_paused = paused
	map_buttons.clear()
	room_buttons.clear()
	upgrade_buttons.clear()
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.show()
	_reaction_left = 0.0
	reaction_label.hide()
	reaction_marker.hide()
	combo_anchor.hide()
	protection_label.hide()
	pause_button.hide()
	var panel := Panel.new()
	panel.position = Vector2(92,22)
	panel.size = Vector2(776,496)
	panel.add_theme_stylebox_override("panel",_style(Color("0b1224"),Color("d3a859"),2))
	overlay.add_child(panel)
	var title := tr2("夜访农场 · 自由试玩","NIGHT FARM · FREE PLAY") if profile.free_selection else tr2("夜访农场 · 四图闯关","NIGHT FARM · HARVEST RUN")
	if paused: title = tr2("休息一下","PAUSED")
	elif result.get("entered_map",false): title = tr2("行前准备","READY FOR A NEW MAP")
	elif result.get("map_complete",false): title = tr2("四图全部通关！","ALL FOUR MAPS CLEARED!") if profile.cleared.all(func(value): return value) else tr2("地图通关！","MAP COMPLETE!")
	elif result.get("caught",false): title = tr2("被农夫抓住 · 可重试本关","CAUGHT · TRY THIS ROOM AGAIN")
	elif result.has("score"): title = tr2("小关完成 · 购买增益再出发","ROOM COMPLETE · UPGRADE & GO")
	_label(panel,Rect2(18,8,740,39),title,25 if language == "zh" else 21)
	var summary := tr2("试玩模式：全部地图和小关可直接选择；金币保留，换图增益清零。","Playtest: pick any map and room. Keep coins; reset buffs on map entry.") if profile.free_selection else tr2("四张地图，每图四个小关；金币跨图保留，增益换图清零。","4 maps × 4 rooms. Keep coins between maps; buffs reset.")
	if result.has("score"):
		summary = tr2("%d-%d 得分 %d　收集 %d　奖励 %d 币","%d-%d  Score %d   Items %d   +%d coins") % [result.get("map",1),result.level,result.score,result.get("eggs",0),result.reward]
		if result.get("map_complete",false): summary += tr2("　地图总分 %d","   Map total %d") % result.get("total",0)
	elif result.get("entered_map",false): summary = tr2("金币已保留，增益已归零；现在可以购买本图增益。","Coins kept, buffs reset. Buy new buffs before entering the first room.")
	_label(panel,Rect2(16,49,744,27),summary,14)
	for i in range(4):
		var index := i+1
		var state := tr2("试玩开放","Open to test") if profile.free_selection else tr2("未解锁","Locked") if index > profile.unlocked_maps else (tr2("已通关","Cleared") if profile.cleared[i] else tr2("已解锁","Unlocked"))
		var button := _button(panel,Rect2(24+i*184,82,174,51),"%d %s\n%s" % [index,ArcadeThemes.name_for(index,language),state],func(): map_selection_changed.emit(index))
		button.add_theme_font_size_override("font_size",15)
		button.disabled = paused or not profile.can_visit_map(index)
		if index == _map_selected: button.add_theme_stylebox_override("normal",_style(Color("584127"),Color("ffe0a0"),2))
		map_buttons.append(button)
	var active := _map_selected == profile.active_map
	var room := _selected if profile.free_selection else (profile.unlocked if active and not profile.map_complete else 1)
	for i in range(4):
		var level := i+1
		var state := tr2("已完成","Done") if active and profile.map_complete else (tr2("待进入","Next") if level == room else (tr2("已完成","Done") if active and level < profile.unlocked else tr2("未解锁","Locked")))
		if profile.free_selection: state = tr2("已选","Selected") if level == room else tr2("试玩","Test")
		var button := _button(panel,Rect2(24+i*184,143,174,34),"%d-%d  %s" % [_map_selected,level,state],func(): selection_changed.emit(level))
		button.add_theme_font_size_override("font_size",14)
		button.disabled = paused or (not profile.free_selection and (not active or profile.map_complete or level != room))
		if profile.free_selection and level == room: button.add_theme_stylebox_override("normal",_style(Color("584127"),Color("ffe0a0"),2))
		room_buttons.append(button)
	_label(panel,Rect2(18,186,740,26),tr2("金币 %d（跨图保留）　｜　本图最高总分 %d","Coins %d (keep across maps)   |   Map best %d") % [profile.coins,profile.map_best[_map_selected-1]],16)
	var shop_enabled := not paused and profile.can_visit_map(_map_selected)
	var names := [tr2("拾取范围","Pickup reach"),tr2("额外收获","Bonus yield"),tr2("资源窝补货","Nest refill")]
	var details := [tr2("扩大整圈拾取的半径","Increase the whole pickup radius"),tr2("每级增加 10% 双份概率","+10% extra yield chance per level"),tr2("缩短空草窝的补货间隔","Empty nests refill sooner")]
	for i in range(3):
		var index := i
		var grade: int = profile.upgrades[i] if active and not profile.map_complete else 0
		var price := profile.cost(i) if active and not profile.map_complete else ArcadeProfile.COSTS[0]
		_label(panel,Rect2(20+i*248,220,240,25),"%s  Lv.%d" % [names[i],grade],16)
		_label(panel,Rect2(20+i*248,247,240,22),details[i],12)
		var button := _button(panel,Rect2(28+i*248,276,224,32),tr2("已满级","MAX") if price < 0 else tr2("升级 · %d 币","Upgrade · %d coins") % price,func(): upgrade_requested.emit(index))
		button.disabled = not shop_enabled or price < 0 or profile.coins < price
		upgrade_buttons.append(button)
	_label(panel,Rect2(18,320,740,43),tr2("WASD 移动 · 点击圈内物品收整圈 · Esc 暂停\n每小关 60 秒；鸡舍 2～4 关有蛇蛋，捡到后侧移躲开。","WASD move · Click an item to gather the ring · Esc pause\n60s per room. Chicken rooms 2–4 hide snake eggs: sidestep the dash."),14)
	menu_save_help = _label(panel,Rect2(18,368,740,22),tr2("金币保留｜换图出发或购买新图增益时，旧图增益归零；开始只需点一次","Keep coins. Starting/buying in a new map resets buffs. Start needs one click."),12)
	menu_storage_label = _label(panel,Rect2(18,367,740,48),"",12)
	menu_storage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_storage_label.add_theme_color_override("font_color",Color("ffd38a"))
	update_storage_status(profile)
	var caption := tr2("继续游戏","Resume") if paused else (tr2("出发：%d-%d · %d 秒","Play %d-%d · %d seconds") % [_map_selected,room,round_duration] if active and not profile.map_complete else tr2("进入 %s · 金币保留，增益归零","Enter %s · keep coins, reset buffs") % ArcadeThemes.name_for(_map_selected,language))
	if profile.free_selection and not paused: caption = tr2("试玩：%d-%d · 60 秒","Playtest %d-%d · 60 seconds") % [_map_selected,room]
	primary_button = _button(panel,Rect2(24,423,500,44),caption,func():
		if _paused: pause_requested.emit()
		else: start_requested.emit(room,_map_selected))
	primary_button.add_theme_stylebox_override("normal",_style(Color("6e4d24"),Color("ffe0a0"),2))
	primary_button.add_theme_font_size_override("font_size",15)
	_button(panel,Rect2(538,423,94,44),"中文" if language == "en" else "English",func():
		language = "zh" if language == "en" else "en"
		show_menu(_profile,_selected,_result,_paused,_map_selected))
	if paused: _button(panel,Rect2(646,423,106,44),tr2("回菜单","Menu"),func(): abandon_requested.emit())
	else:
		var restart := _button(panel,Rect2(646,423,106,44),tr2("重开此图\n增益清零","Restart map\nreset buffs"),func(): restart_requested.emit(_map_selected))
		restart.add_theme_font_size_override("font_size",12)
		restart.disabled = not active
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
	pause_button.show()

func update_danger(level: float, seen: bool, farmer_present: bool) -> void:
	danger_label.text = tr2("农夫正在追赶！","Farmer chasing!") if farmer_present else tr2("警戒 %d / 100","Alert %d / 100") % floori(level)
	danger_label.add_theme_color_override("font_color",Color("ff8b72") if seen or farmer_present else Color("ffe5ad"))
