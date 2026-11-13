class_name ArcadeUI
extends CanvasLayer

signal start_requested(level: int)
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
var danger_label: Label
var pause_button: Button
var round_duration := 60
var _toast_left := 0.0
var _profile: ArcadeProfile
var _selected := 1
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
	_toast_left = maxf(0.0,_toast_left-delta)
	toast.visible = _toast_left > 0.0 and not overlay.visible
	if not get_tree().paused: _combo_pop_age += delta
	combo_anchor.visible = _current_chain >= 2 and not overlay.visible
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
	protection_label.position = Vector2(clampf(point.x-75,15,795),clampf(point.y+8,80,467))
	protection_label.text = tr2("开局保护 %ds","Protected %ds") % ceili(protection_left)
	protection_label.visible = protection_left > 0 and not overlay.visible

func announce(zh: String, en: String) -> void:
	toast.text = tr2(zh,en)
	_toast_left = 3.0

func update_game(score: int, eggs: int, chain: int, multiplier: int, combo_left: float, seconds: float, level: int) -> void:
	score_label.text = tr2("得分 %d","Score %d") % score
	egg_label.text = tr2("鸡蛋 %d","Eggs %d") % eggs
	time_label.text = "%d:%02d" % [ceili(seconds)/60,ceili(seconds)%60]
	time_label.add_theme_color_override("font_color",Color("ff9d6e") if seconds > 0 and seconds <= 10 else Color("ffe5ad"))
	if chain > _current_chain and chain >= 5 and chain%5 == 0:
		_combo_pop_age = 0.0
		_cheer_text = tr2("漂亮！","NICE!") if chain < 10 else (tr2("继续冲！","KEEP GOING!") if chain < 20 else tr2("停不下来！","UNSTOPPABLE!"))
	_current_chain = chain
	_current_multiplier = multiplier
	combo_label.text = tr2("连击 ×%d","COMBO ×%d") % chain
	combo_anchor.visible = chain >= 2 and not overlay.visible
	combo_bar.value = combo_left
	stage_label.text = ("%d · " % level) + (STAGE_EN if language == "en" else STAGE_ZH)[level-1]
	hint.text = tr2("左键捡圈内蛋 / 连点草窝　 WASD 移动","Left-click nearby eggs / nests   WASD move")

func show_menu(profile: ArcadeProfile, selected: int, result := {}, paused := false) -> void:
	_profile = profile
	_selected = selected
	_result = result
	_paused = paused
	_running = paused
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.show()
	combo_anchor.hide()
	protection_label.hide()
	pause_button.hide()
	var panel := Panel.new()
	panel.position = Vector2(102,42)
	panel.size = Vector2(756,456)
	panel.add_theme_stylebox_override("panel",_style(Color("0b1224"),Color("d3a859"),2))
	overlay.add_child(panel)
	var title := tr2("夜访鸡舍 · 捡蛋冲分","NIGHT COOP: EGG RUSH")
	if paused: title = tr2("休息一下","PAUSED")
	elif not result.is_empty(): title = tr2("被农夫抓住 · 提前结算","CAUGHT · RUN ENDED") if result.get("caught",false) else tr2("本局收获","ROUND COMPLETE")
	_label(panel,Rect2(20,14,716,41),title,28 if language == "zh" else 25)
	var summary := tr2("左键点蛋附近即可捡取，走近草窝可以连续取蛋。","Left-click near an egg to collect; move close to nests for repeated pickups.")
	if not result.is_empty():
		summary = tr2("得分 %d　鸡蛋 %d　奖励 %d 币　%s","Score %d   Eggs %d   +%d coins   %s") % [result.score,result.get("eggs",0),result.reward,tr2("新纪录！","NEW BEST!") if result.record else ""]
	_label(panel,Rect2(15,60,726,28),summary,15)
	_label(panel,Rect2(18,91,720,24),tr2("选择关卡 · 完成一局即可解锁下一关","CHOOSE A STAGE · Finish a round to unlock the next"),15)
	for i in range(4):
		var level := i+1
		var name: String = (STAGE_EN if language == "en" else STAGE_ZH)[i]
		var text := "%d  %s" % [level,name]
		if level > profile.unlocked: text += tr2("\n未解锁","\nLocked")
		elif level == selected: text += tr2("\n已选择","\nSelected")
		var button := _button(panel,Rect2(24+i*180,120,168,54),text,func(): selection_changed.emit(level))
		button.disabled = paused or level > profile.unlocked
		if level == selected: button.add_theme_stylebox_override("normal",_style(Color("584127"),Color("ffe0a0"),2))
	_label(panel,Rect2(18,182,720,24),tr2("钱币 %d　｜　本关最高分 %d","Coins %d   |   Stage best %d") % [profile.coins,profile.best[selected-1]],17)
	var names := [tr2("连收范围","Gather radius"),tr2("额外收获","Bonus eggs"),tr2("鸡窝补货","Nest refill")]
	var details := [tr2("扩大拾取圈，连收附近更多蛋","More reach and nearby eggs"),tr2("每级增加 10%% 双份概率","+10%% chance of an extra egg / level"),tr2("缩短空鸡窝的补货间隔","Empty nests refill sooner")]
	for i in range(3):
		var index := i
		var price := profile.cost(i)
		_label(panel,Rect2(20+i*240,215,236,24),"%s  Lv.%d" % [names[i],profile.upgrades[i]],17)
		_label(panel,Rect2(20+i*240,241,236,25),details[i].replace("%%","%"),12)
		var text := tr2("已满级","MAX LEVEL") if price < 0 else tr2("升级 · %d 币","Upgrade · %d coins") % price
		var button := _button(panel,Rect2(30+i*240,274,216,35),text,func(): upgrade_requested.emit(index))
		button.disabled = paused or price < 0 or profile.coins < price
	var guide := tr2("WASD 移动 · 左键捡附近蛋 · Esc 暂停\n开局保护 3 秒；躲开鸡的视野，警戒过高会引来农夫。","WASD move · Left-click nearby eggs · Esc pause\n3-second start protection. Avoid hen sight; high alert brings the farmer.")
	_label(panel,Rect2(18,319,720,43),guide,14)
	if not profile.saved:
		_label(panel,Rect2(18,361,720,20),tr2("当前浏览器无法保存进度，关闭后升级可能丢失。","Storage is unavailable; upgrades may be lost when this tab closes."),12)
	var primary := _button(panel,Rect2(24,389,490,44),tr2("继续游戏","Resume") if paused else tr2("开始第 %d 关 · %d 秒","Play stage %d · %d seconds") % [selected,round_duration],func():
		if _paused: pause_requested.emit()
		else: start_requested.emit(_selected))
	primary.add_theme_stylebox_override("normal",_style(Color("6e4d24"),Color("ffe0a0"),2))
	_button(panel,Rect2(530,389,95,44),"中文" if language == "en" else "English",func():
		language = "zh" if language == "en" else "en"
		show_menu(_profile,_selected,_result,_paused))
	if paused:
		_button(panel,Rect2(640,389,92,44),tr2("回菜单","Menu"),func(): abandon_requested.emit())
	else:
		_label(panel,Rect2(640,389,92,44),tr2("每 5 分\n换 1 币","5 points\n= 1 coin"),13)
	primary.grab_focus()

func hide_menu() -> void:
	overlay.hide()
	pause_button.show()

func update_danger(level: float, seen: bool, farmer_present: bool) -> void:
	danger_label.text = tr2("农夫正在追赶！","Farmer chasing!") if farmer_present else tr2("警戒 %d / 100","Alert %d / 100") % floori(level)
	danger_label.add_theme_color_override("font_color",Color("ff8b72") if seen or farmer_present else Color("ffe5ad"))
