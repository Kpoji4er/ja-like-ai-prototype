extends Node3D

const W := 32
const H := 26
const C := 1.8
const MAX_AP := 20
var solid := {}
var cover := {}
var doors: Dictionary={}
var windows: Dictionary={}
var units: Array[Dictionary] = []
var selected: Dictionary = {}
var world: Node3D
var camera: Camera3D
var camera_target := Vector3(0,0,0)
var yaw := 0.52
var zoom := 48.0
var busy := false
var enemy_turn := false
var turn := 1
var won := false
var aimed := false
var hud: CanvasLayer
var status: Label
var detail: Label
var hint: Label
var turn_label: Label
var feed: RichTextLabel
var cards: Array[Button] = []
var card_labels: Array[Label] = []
var health_bars: Array[ColorRect] = []
var map: Control
var cursor: MeshInstance3D
var path_nodes: Array[MeshInstance3D] = []
var hover_cell := Vector2i(-1,-1)
var hover_unit: Dictionary = {}
var current_path: Array[Vector2i] = []
var log_lines: Array[String] = []
var rng := RandomNumberGenerator.new()
var cinematic := false
var time := 0.0
var test_mode := false
var capture_mode := false
var demo_mode:=false
var input_test_mode:=false
var save_path:="res://../saves/quicksave.json"
var sound: AudioStreamPlayer
var explosion_sound: AudioStreamPlayer
var tactics: Node
var effects: Node3D
var save_system: RefCounted
var outcome_panel: Control
var menu_panel: Control
var action_buttons: Dictionary={}
var camera_shake:=0.0
var previous_target:=Vector3.ZERO
var tactical_overlay: MeshInstance3D
var explosives: Node3D
var sector_index:=0
var campaign: Node3D
var mission_heading: Label
var mission_goal: Label
var sector_heading: Label
var minimap_heading: Label

func to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x-(W-1)*0.5)*C,0,(cell.y-(H-1)*0.5)*C)

func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x/C+(W-1)*0.5),roundi(p.z/C+(H-1)*0.5))

func _ready():
	rng.seed = 2026
	test_mode = "--campaign-soak" in OS.get_cmdline_user_args() or "--campaign-test" in OS.get_cmdline_user_args() or "--test" in OS.get_cmdline_user_args() or "--soak" in OS.get_cmdline_user_args()
	demo_mode="--demo" in OS.get_cmdline_user_args()
	input_test_mode="--ui-test" in OS.get_cmdline_user_args()
	capture_mode = "--campaign-gallery" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--gallery" in OS.get_cmdline_user_args() or "--perf" in OS.get_cmdline_user_args() or demo_mode
	if capture_mode: get_viewport().gui_disable_input=true
	setup_environment()
	campaign=load("res://campaign.gd").new()
	add_child(campaign)
	campaign.initialize(self)
	stage_sector(campaign.index)
	campaign.populate()
	campaign.setup_visuals()
	selected = units[0]
	effects=load("res://effects.gd").new()
	add_child(effects)
	effects.initialize(self)
	tactics=load("res://tactics.gd").new()
	add_child(tactics)
	tactics.initialize(self)
	save_system=load("res://save_system.gd").new()
	cursor = ring_mesh(0.7,Color("dbbf75"))
	add_child(cursor)
	cursor.visible = false
	setup_ui()
	tactical_overlay=load("res://tactical_overlay.gd").new()
	add_child(tactical_overlay)
	tactical_overlay.initialize(self)
	if not test_mode: setup_audio()
	note("Миссия %d / 4: %s. [F1] — задача и брифинг, [J] — взаимодействие." % [campaign.index+1,campaign.TITLES[campaign.index]])
	refresh_ui()
	if "--campaign-soak" in OS.get_cmdline_user_args():
		await load("res://campaign_tests.gd").new().soak(self)
	elif "--campaign-test" in OS.get_cmdline_user_args():
		await load("res://campaign_tests.gd").new().run(self)
	elif "--campaign-gallery" in OS.get_cmdline_user_args():
		await load("res://campaign_tests.gd").new().gallery(self)
	elif "--soak" in OS.get_cmdline_user_args():
		await load("res://soak_tests.gd").new().run(self)
	elif test_mode:
		if Engine.has_meta("restart_test_pending"):
			var fresh := turn==1 and not busy and not won and selected==units[0]
			for u in units:
				fresh = fresh and u.hp==100 and u.ap==MAX_AP
			if fresh:
				print("ALL TESTS PASSED: navigation, LOS, cover, movement/AP, stance, shooting, AI, victory, scene restart")
				get_tree().quit(0)
			else:
				push_error("TEST FAILED: scene restart state")
				get_tree().quit(1)
		else: call_deferred("run_tests")
	elif input_test_mode:
		await load("res://ui_smoke.gd").new().run(self)
	elif "--perf" in OS.get_cmdline_user_args():
		await load("res://performance_check.gd").new().run(self)
	elif demo_mode:
		await load("res://demo.gd").new().run(self)
	elif "--gallery" in OS.get_cmdline_user_args():
		await load("res://capture_gallery.gd").new().run(self)
	elif "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3).timeout
		await RenderingServer.frame_post_draw
		var filename:="preview-compat.png" if "--compat-shot" in OS.get_cmdline_user_args() else "preview.png"
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/"+filename))
		print("SCREENSHOT_SAVED")
		get_tree().quit()

func setup_environment():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a6ac95")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("adbfd2")
	env.ambient_light_energy = 0.43
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled=true
	env.adjustment_contrast=1.06
	env.adjustment_saturation=1.08
	env.ssao_enabled = true
	env.ssao_radius = 1.7
	env.ssao_intensity = 1.5
	env.fog_enabled = true
	env.fog_light_color = Color("b3ad88")
	env.fog_density = 0.0018
	var environment := WorldEnvironment.new()
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("ffe8c9")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	sun.shadow_bias = 0.03
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.far = 200
	add_child(camera)
	update_camera()

func update_camera():
	camera.size = zoom
	camera.position = camera_target+Vector3(sin(yaw)*45,48,cos(yaw)*45)
	camera.look_at(camera_target)
	if camera_shake>0:
		camera.h_offset=sin(time*83)*camera_shake
		camera.v_offset=cos(time*67)*camera_shake*0.6
	else:
		camera.h_offset=0
		camera.v_offset=0

func ring_mesh(radius: float, color: Color) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = radius-0.04
	m.outer_radius = radius+0.04
	m.rings = 32
	m.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = m
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func add_unit(title: String, team: int, cell: Vector2i, index: int, accuracy: int):
	var node: Node3D = world.soldier(team,index)
	add_child(node)
	node.position = to_world(cell)
	if team==1: node.rotation.y = PI
	var ring := ring_mesh(0.53,Color("dbbd75") if team==0 else Color("b65841"))
	node.add_child(ring)
	ring.position.y = 0.055
	var label := Label3D.new()
	label.text = title
	label.font_size = 34
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffe6a3") if team==0 else Color("e79173")
	label.outline_modulate = Color("1b221a")
	label.outline_size = 8
	node.add_child(label)
	label.position.y = 2.55
	units.append({"name":title,"team":team,"cell":cell,"node":node,"ring":ring,"label":label,"hp":100,"ap":MAX_AP,"accuracy":accuracy,"crouched":false,"index":index})

func style(bg: String, border: String = "595640", width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg)
	s.border_color = Color(border)
	s.set_border_width_all(width)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func panel(pos: Vector2, dims: Vector2, parent: Node, bg: String = "17201eef") -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = dims
	p.add_theme_stylebox_override("panel",style(bg))
	parent.add_child(p)
	return p

func label(text: String, pos: Vector2, font_size: int, color: String, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",Color(color))
	parent.add_child(l)
	return l

func button(text: String, pos: Vector2, dims: Vector2, callback: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode=Control.FOCUS_NONE
	b.position = pos
	b.size = dims
	b.add_theme_stylebox_override("normal",style("25302bee","777052"))
	b.add_theme_stylebox_override("hover",style("39443aff","ceb779"))
	b.add_theme_stylebox_override("pressed",style("4b4c34ff","e2c480",2))
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",Color("e2d8b9"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func setup_ui():
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var top := panel(Vector2(24,22),Vector2(1552,72),root)
	label("JA",Vector2(18,5),42,"dfc38a",top)
	label("JA-LIKE  /  AI PROTOTYPE",Vector2(117,12),18,"e2d9bb",top)
	label("0.3  /  КАМПАНИЯ «ОМЕРТА»",Vector2(117,38),12,"8f9b88",top)
	sector_heading=label("A9  /  ОМЕРТА",Vector2(530,12),21,"e2d9bb",top)
	label("СЕВЕРНЫЙ СЕКТОР    •    17:42",Vector2(530,40),12,"a8ae97",top)
	turn_label = label("ХОД 01  /  ВАШ ОТРЯД",Vector2(1125,22),19,"d8be80",top)
	var mission := panel(Vector2(24,110),Vector2(655,94),root,"19231cdb")
	button("ЗАДАЧА [J]",Vector2(510,8),Vector2(132,29),campaign.interact,mission)
	mission_heading=label("ОПЕРАЦИЯ",Vector2(16,12),16,"dfc38a",mission)
	mission_goal=label("Задача",Vector2(16,40),17,"e3dfc9",mission)
	status = label("Противников в секторе: 4",Vector2(16,66),13,"a4b096",mission)
	var minimap_panel := panel(Vector2(1332,110),Vector2(244,220),root)
	minimap_heading=label("РАЗВЕДКА  /  A9",Vector2(14,9),13,"c5b88e",minimap_panel)
	map = load("res://minimap.gd").new()
	map.game = self
	map.position = Vector2(14,38)
	map.size = Vector2(216,166)
	minimap_panel.add_child(map)
	var bottom := panel(Vector2(24,810),Vector2(1552,168),root)
	label("A.I.M.  /  ГРУППА ВЫСАДКИ",Vector2(15,9),13,"a8af93",bottom)
	for i in range(3):
		var b := button("",Vector2(14+i*218,36),Vector2(208,116),func(): select_unit(units[i]),bottom)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cards.append(b)
		portrait(b,i)
		var info := label("",Vector2(78,10),15,"e0d9b8",b)
		info.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card_labels.append(info)
		var health_background := ColorRect.new()
		health_background.position=Vector2(78,100)
		health_background.size=Vector2(113,5)
		health_background.color=Color("20271f")
		health_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(health_background)
		var health := ColorRect.new()
		health.size=Vector2(113,5)
		health.color=Color("8b9e65")
		health.mouse_filter=Control.MOUSE_FILTER_IGNORE
		health_background.add_child(health)
		health_bars.append(health)
	detail = label("",Vector2(690,12),17,"e3d8b8",bottom)
	hint = label("",Vector2(690,40),13,"aeb89f",bottom)
	var actions: Array=[
		["aim","ПРИЦЕЛ F",toggle_aim],["crouch","ПОЗА C",toggle_crouch],
		["burst","ОЧЕРЕДЬ B",func(): tactics.set_mode("burst")],["reload","МАГАЗИН R",func(): tactics.reload_weapon()],
		["watch","РЕАКЦИЯ O",tactics.toggle_watch],["heal","АПТЕЧКА H",func(): tactics.set_mode("heal")],
		["grenade","ГРАНАТА G",func(): tactics.set_mode("grenade")],["help","БРИФИНГ F1",toggle_menu]]
	for i in range(actions.size()):
		var data: Array=actions[i]
		var b:=button(data[1],Vector2(690+(i%4)*116,74+(i/4)*41),Vector2(109,35),data[2],bottom)
		b.add_theme_font_size_override("font_size",12)
		var tips: Dictionary={"aim":"8 ОД за прицельный выстрел, +18% точности.","crouch":"2 ОД: сменить позу. Сидя: +9% точности, врагу −12%.","burst":"9 ОД и 3 патрона. Три выстрела с пониженной точностью.","reload":"5 ОД: пополнить магазин из ограниченного запаса.","watch":"Резерв 6 ОД: один ответный выстрел при движении врага. Повторное нажатие отменяет резерв.","heal":"6 ОД и аптечка. Выберите себя или соседнего бойца. Фокс лечит лучше.","grenade":"8 ОД. Бросок до 7 клеток; радиус 2,4 клетки. Урон получают и союзники.","help":"Задание, управление, сохранение и загрузка."}
		b.tooltip_text=tips[data[0]]
		action_buttons[data[0]]=b
	action_buttons.end=button("КОНЕЦ ХОДА  [ПРОБЕЛ]",Vector2(1178,94),Vector2(353,50),end_turn,bottom)
	button("МЕНЮ / СОХРАНИТЬ  [ESC]",Vector2(1178,36),Vector2(353,43),toggle_menu,bottom)
	var feed_panel := panel(Vector2(24,668),Vector2(490,124),root,"19231cd9")
	label("РАДИО  /  ТАКТИЧЕСКИЙ КАНАЛ",Vector2(14,8),12,"b5a77b",feed_panel)
	feed=RichTextLabel.new()
	feed.position=Vector2(14,34)
	feed.size=Vector2(462,78)
	feed.add_theme_font_size_override("normal_font_size",14)
	feed.add_theme_color_override("default_color",Color("d2d3b7"))
	feed.scroll_following=true
	feed.mouse_filter=Control.MOUSE_FILTER_IGNORE
	feed_panel.add_child(feed)
	var help_bar := panel(Vector2(529,757),Vector2(1047,36),root,"19231ce0")
	label("ЛКМ: действие   •   WASD / Q/E: камера   •   Колесо: масштаб   •   F5 / F9: сохранить / загрузить   •   F1: помощь",Vector2(14,8),13,"e1dcc6",help_bar)

func portrait(parent: Control, index: int):
	var container := SubViewportContainer.new()
	container.position=Vector2(9,10)
	container.size=Vector2(59,94)
	container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(118,188)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	viewport.msaa_3d=Viewport.MSAA_2X
	container.add_child(viewport)
	var actor: Node3D = world.soldier(0,index)
	actor.rotation.y=-0.2
	viewport.add_child(actor)
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("26332a")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("ccd2b9")
	env.ambient_light_energy=0.5
	var environment := WorldEnvironment.new()
	environment.environment=env
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-25,-145,0)
	light.light_energy=1.0
	viewport.add_child(light)
	var portrait_camera := Camera3D.new()
	viewport.add_child(portrait_camera)
	portrait_camera.position=Vector3(0,1.49,-2.8)
	portrait_camera.fov=21
	portrait_camera.look_at(Vector3(0,1.4,0))

func select_unit(unit: Dictionary):
	if busy or unit.hp<=0 or won: return
	selected = unit
	tactics.mode="normal"
	ui_invalidate()
	clear_path()
	refresh_ui()

func refresh_ui():
	if not is_instance_valid(status): return
	if is_instance_valid(tactical_overlay): tactical_overlay.rebuild()
	var enemies := 0
	for u in units:
		if u.team==1 and u.hp>0 and u.visible: enemies+=1
		u.ring.visible = u.hp>0 and u.visible and not cinematic
		u.label.visible=u.hp>0 and u.visible and not cinematic
		u.ring.scale = Vector3.ONE*(1.23 if u==selected else 0.82)
		if u.hp>0: u.label.text = u.name+"\n"+("◉ ПРИКРЫТИЕ" if u.watch else str(u.hp)+" HP")
	status.text=campaign.objective_text()
	mission_heading.text="%d / 4  •  %s" % [campaign.index+1,campaign.TITLES[campaign.index]]
	mission_goal.text=campaign.GOALS[campaign.index]
	sector_heading.text=campaign.SECTORS[campaign.index]
	minimap_heading.text="РАЗВЕДКА / "+campaign.SECTORS[campaign.index].split(" /")[0]
	turn_label.text = "ХОД %02d  /  %s" % [turn,"ПРОТИВНИК" if enemy_turn else "ВАШ ОТРЯД"]
	for i in range(cards.size()):
		var u := units[i]
		card_labels[i].text = "[%d] %s%s\nHP %d / 100\nОД %02d / 20\n%s" % [i+1,u.name," ◂" if u==selected else "",u.hp,u.ap,"ВЫБЫЛ" if u.hp<=0 else ("ПРИКРЫВАЕТ" if u.watch else ("СИДИТ" if u.crouched else "ГОТОВ"))]
		health_bars[i].size.x=113.0*u.hp/100.0
		cards[i].add_theme_stylebox_override("normal",style("364336ee" if u==selected else "25302bee","ccb478" if u==selected else "5b604b",2 if u==selected else 1))
	detail.text = "%s / %s  •  %d/%d +%d  •  ОД %d" % [selected.name,["АК-74","MP5","M14"][selected.index],selected.ammo,selected.capacity,selected.reserve,selected.ap]
	hint.text = "Прицел: 8 ОД / +18%" if aimed else "Огонь: 6 ОД   •   Шаг: 2   •   Прикрытие: 6"
	if tactics.mode=="burst": hint.text="Очередь: 9 ОД / 3 патрона / −15% точности"
	if tactics.mode=="heal": hint.text="ЛКМ по бойцу рядом / 6 ОД / аптечек: %d" % selected.medkits
	if tactics.mode=="grenade": hint.text="Бросок: 8 ОД / радиус 2,4 / гранат: %d" % selected.grenades
	for key in action_buttons:
		var b: Button=action_buttons[key]
		b.disabled=busy or won or selected.hp<=0
		var active: bool=(key=="aim" and aimed) or (key=="crouch" and selected.crouched) or (key=="watch" and selected.watch) or key==tactics.mode
		b.add_theme_stylebox_override("normal",style("555334ff" if active else "25302bee","ddc17c" if active else "777052",2 if active else 1))
	if action_buttons.has("help"): action_buttons.help.disabled=busy
	map.queue_redraw()

func note(text: String):
	log_lines.append(text)
	if log_lines.size()>4: log_lines.pop_front()
	if is_instance_valid(feed): feed.text = "\n".join(log_lines)
	print(text)

func _process(delta: float):
	if input_test_mode:
		if not busy and not is_instance_valid(menu_panel): update_hover()
		return
	if demo_mode:
		time+=delta
		camera_shake=maxf(0,camera_shake-delta*0.65)
		camera_target=camera_target.lerp(selected.node.position+Vector3(4,0,-1),delta*0.5)
		update_camera()
		return
	if capture_mode: return
	if is_instance_valid(menu_panel): return
	time += delta
	camera_shake=maxf(0,camera_shake-delta*0.65)
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if Input.is_physical_key_pressed(KEY_Q): yaw += delta*0.8
	if Input.is_physical_key_pressed(KEY_E): yaw -= delta*0.8
	camera_target += direction.rotated(Vector3.UP,yaw)*delta*17
	camera_target.x = clampf(camera_target.x,-25,25)
	camera_target.z = clampf(camera_target.z,-20,20)
	update_camera()
	if not busy and not won: update_hover()

func _unhandled_input(event: InputEvent):
	if capture_mode: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE,KEY_F1]:
			toggle_menu()
			return
		if event.physical_keycode==KEY_F5:
			quicksave()
			return
		if event.physical_keycode==KEY_F9:
			quickload()
			return
	if is_instance_valid(menu_panel): return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom = maxf(18,zoom-2.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(68,zoom+2.5)
		if event.button_index==MOUSE_BUTTON_RIGHT:
			aimed=false
			tactics.mode="normal"
			ui_invalidate()
			refresh_ui()
		if event.button_index==MOUSE_BUTTON_LEFT and not busy and not won:
			if tactics.mode=="grenade": tactics.throw_grenade(hover_cell)
			elif tactics.mode=="heal" and not hover_unit.is_empty(): tactics.heal(hover_unit)
			elif tactics.mode=="heal": note("Выберите себя или соседнего бойца для лечения.")
			elif doors.has(hover_cell) and hover_unit.is_empty(): interact_door(hover_cell)
			elif explosives.target_at(hover_cell) and hover_unit.is_empty(): explosives.shoot(hover_cell)
			elif not hover_unit.is_empty():
				if hover_unit.team==0: select_unit(hover_unit)
				else: shoot(selected,hover_unit)
			elif current_path.size()>1: move_unit(selected,current_path.duplicate())
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: end_turn()
			KEY_J: campaign.interact()
			KEY_C: toggle_crouch()
			KEY_F: toggle_aim()
			KEY_B: tactics.set_mode("burst")
			KEY_G: tactics.set_mode("grenade")
			KEY_H: tactics.set_mode("heal")
			KEY_O: tactics.toggle_watch()
			KEY_R: tactics.reload_weapon()
			KEY_T:
				world.roofs_forced_hidden=not world.roofs_forced_hidden
				world.update_cutaways()
			KEY_V:
				tactical_overlay.enabled=not tactical_overlay.enabled
				tactical_overlay.rebuild()
				note("Сетка ОД: зелёные клетки оставляют 6 ОД на выстрел, жёлтые — без запаса на выстрел." if tactical_overlay.enabled else "Сетка ОД скрыта.")
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_1: select_unit(units[0])
			KEY_2: select_unit(units[1])
			KEY_3: select_unit(units[2])
			KEY_TAB:
				for offset in range(1,4):
					var next := units[(selected.index+offset)%3]
					if next.hp>0:
						select_unit(next)
						break
			KEY_F2:
				cinematic = not cinematic
				hud.visible = not cinematic
				refresh_ui()
				world.update_cutaways()
				clear_path()
			KEY_F12:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/screenshot.png"))
			KEY_HOME:
				camera_target=Vector3.ZERO
				yaw=0.52
				zoom=48

func unit_at(cell: Vector2i) -> Dictionary:
	for u in units:
		if u.hp>0 and u.cell==cell: return u
	return {}

func walkable(cell: Vector2i, actor: Dictionary = {}) -> bool:
	if cell.x<0 or cell.y<0 or cell.x>=W or cell.y>=H: return false
	if solid.has(cell) or cover.has(cell): return false
	var occupant := unit_at(cell)
	return occupant.is_empty() or occupant==actor

func find_path(start: Vector2i, goal: Vector2i, actor: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not walkable(goal,actor): return result
	var frontier: Array[Vector2i] = [start]
	var came := {start:start}
	var index := 0
	while index<frontier.size():
		var cell := frontier[index]
		index+=1
		if cell==goal: break
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+d
			if not came.has(next) and walkable(next,actor):
				came[next]=cell
				frontier.append(next)
	if not came.has(goal): return result
	var cell := goal
	while cell!=start:
		result.push_front(cell)
		cell=came[cell]
	result.push_front(start)
	return result

func update_hover():
	if cinematic: return
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var intersection = Plane(Vector3.UP,0).intersects_ray(from,dir)
	if intersection==null: return
	var cell := to_cell(intersection)
	var target: Dictionary = {}
	var best := 34.0
	for u in units:
		if u.hp<=0 or not u.visible: continue
		var screen := camera.unproject_position(u.node.position+Vector3.UP)
		var distance := mouse.distance_to(screen)
		if distance<best:
			best=distance
			target=u
	if target.is_empty() and tactics.mode not in ["grenade","heal"]:
		for barrel_cell in explosives.barrels:
			if explosives.target_at(barrel_cell) and mouse.distance_to(camera.unproject_position(to_world(barrel_cell)+Vector3.UP*0.7))<20: cell=barrel_cell
		for door_cell in doors:
			var door_position: Vector3=doors[door_cell].pivot.global_position+Vector3(0.71,1.0,0)
			if mouse.distance_to(camera.unproject_position(door_position))<23: cell=door_cell
	if cell==hover_cell and target==hover_unit: return
	hover_cell=cell
	hover_unit=target
	clear_path()
	if tactics.mode=="grenade":
		cursor.position=to_world(cell)+Vector3.UP*0.08
		cursor.scale=Vector3(2.4*C/0.7,1,2.4*C/0.7)
		cursor.visible=tactics.grenade_valid(cell)
		var friends:=0
		for u in units:
			if u.team==0 and u.hp>0 and Vector2(u.cell).distance_to(Vector2(cell))<=2.4: friends+=1
		hint.text="ОПАСНО: союзников в радиусе %d" % friends if friends>0 else ("ЛКМ — бросить / 8 ОД" if cursor.visible else "Вне дальности или за стеной")
		return
	if not target.is_empty():
		cursor.position=to_world(target.cell)+Vector3.UP*0.08
		cursor.visible=true
		if target.team==1:
			var chance:=hit_chance(selected,target)
			if tactics.mode=="burst" and chance>0: chance=maxi(10,chance-15)
			hint.text="%s: %d%%  •  %s" % [target.name,chance,"НЕТ ЛИНИИ ОГНЯ" if not line_of_sight(selected.cell,target.cell) else ("УКРЫТИЕ" if protected_from(target,selected) else "ОТКРЫТ")]
		return
	if explosives.target_at(cell):
		cursor.position=to_world(cell)+Vector3.UP*0.08
		cursor.visible=true
		hint.text="БОЧКА: взорвать за 6 ОД / радиус 3 / опасно для своих"
		return
	if doors.has(cell):
		cursor.position=to_world(cell)+Vector3.UP*0.08
		cursor.visible=true
		hint.text=("Закрыть дверь" if doors[cell].open else "Открыть дверь")+" / 2 ОД / подойти вплотную"
		return
	if not walkable(cell,selected): return
	current_path=find_path(selected.cell,cell,selected)
	var cost := (current_path.size()-1)*2
	var available: int=tactics.available_ap(selected)
	if current_path.size()<2: return
	hint.text="Перемещение: %d ОД%s" % [cost,"  •  не хватает ОД" if cost>available else ("  •  отменит прикрытие" if selected.watch else "  •  ЛКМ — идти")]
	for i in range(1,mini(current_path.size(),32)):
		var marker := ring_mesh(0.12,Color("d6c084") if i*2<=available else Color("a85843"))
		add_child(marker)
		marker.position=to_world(current_path[i])+Vector3.UP*0.04
		path_nodes.append(marker)
	cursor.position=to_world(cell)+Vector3.UP*0.06
	cursor.visible=true

func clear_path():
	for marker in path_nodes: marker.queue_free()
	path_nodes.clear()
	current_path.clear()
	if is_instance_valid(cursor):
		cursor.visible=false
		cursor.scale=Vector3.ONE

func line_of_sight(a: Vector2i,b: Vector2i) -> bool:
	var delta_v := Vector2(b-a)
	var steps := int(maxf(absf(delta_v.x),absf(delta_v.y))*4)
	var previous:=a
	for i in range(1,steps):
		var p := Vector2(a).lerp(Vector2(b),float(i)/steps)
		var cell:=Vector2i(roundi(p.x),roundi(p.y))
		if solid.has(cell) and not windows.has(cell): return false
		if cell.x!=previous.x and cell.y!=previous.y:
			var side_a:=Vector2i(cell.x,previous.y)
			var side_b:=Vector2i(previous.x,cell.y)
			if solid.has(side_a) and not windows.has(side_a) and solid.has(side_b) and not windows.has(side_b): return false
		previous=cell
	return true

func protected_from(defender: Dictionary, attacker: Dictionary) -> bool:
	var toward := Vector2(attacker.cell-defender.cell).normalized()
	for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if Vector2(d).dot(toward)>0.2 and cover.has(defender.cell+d): return true
	return false

func hit_chance(attacker: Dictionary,defender: Dictionary,include_aim: bool=true) -> int:
	if not line_of_sight(attacker.cell,defender.cell): return 0
	var distance := Vector2(attacker.cell).distance_to(Vector2(defender.cell))
	if distance>19: return 0
	var chance: float = attacker.accuracy-maxf(0,distance-4)*3
	if protected_from(defender,attacker): chance-=28
	if defender.crouched: chance-=12
	if attacker.crouched: chance+=9
	if include_aim and aimed and attacker==selected and attacker.team==0: chance+=18
	return clampi(roundi(chance),10,95)

func move_unit(unit: Dictionary,path: Array[Vector2i], ai: bool = false):
	var cost := (path.size()-1)*2
	var available: int=unit.ap+(6 if unit.watch else 0)
	if path.size()<2 or cost>available or unit.hp<=0 or path[0]!=unit.cell: return
	if busy and not ai: return
	tactics.cancel_watch(unit)
	busy=true
	clear_path()
	unit.ap-=cost
	refresh_ui()
	for i in range(1,path.size()):
		var destination := to_world(path[i])
		var heading: Vector3 = destination-unit.node.position
		unit.node.rotation.y=atan2(-heading.x,-heading.z)
		var tween := create_tween()
		tween.tween_property(unit.node,"position",destination,0.14)
		var leg_l: Node3D = unit.node.get_node("LegL")
		var leg_r: Node3D = unit.node.get_node("LegR")
		leg_l.rotation.x=0.35 if i%2==0 else -0.35
		leg_r.rotation.x=-leg_l.rotation.x
		await tween.finished
		unit.cell=path[i]
		campaign.moved(unit)
		tactics.update_visibility()
		await tactics.trigger_reactions(unit)
		if unit.hp<=0 or won: break
		map.queue_redraw()
	unit.node.get_node("LegL").rotation.x=0
	unit.node.get_node("LegR").rotation.x=0
	if not ai:
		busy=false
		check_outcome()
		hover_cell=Vector2i(-99,-99)
	refresh_ui()

func toggle_aim():
	if busy or won: return
	tactics.mode="normal"
	aimed=not aimed
	hover_cell=Vector2i(-99,-99)
	refresh_ui()

func toggle_crouch():
	if busy or won or selected.hp<=0 or selected.ap<2: return
	selected.ap-=2
	selected.crouched=not selected.crouched
	selected.node.scale.y=0.74 if selected.crouched else 1.0
	hover_cell=Vector2i(-99,-99)
	refresh_ui()

func ui_invalidate():
	hover_cell=Vector2i(-99,-99)
	hover_unit={}
	clear_path()

func set_door_state(cell: Vector2i, opened: bool):
	var door: Dictionary=doors[cell]
	door.open=opened
	if opened: solid.erase(cell)
	else: solid[cell]=true
	door.pivot.rotation.y=-PI*0.52 if opened else 0

func interact_door(cell: Vector2i):
	if busy or won or not doors.has(cell): return
	if Vector2(selected.cell).distance_to(Vector2(cell))>1.5:
		note("Подойдите к двери вплотную, затем нажмите на неё.")
		return
	if selected.ap<2:
		note("На дверь нужны 2 ОД.")
		return
	if doors[cell].open and not unit_at(cell).is_empty():
		note("Нельзя закрыть дверь: проход занят.")
		return
	selected.ap-=2
	set_door_state(cell,not doors[cell].open)
	note("%s: дверь %s." % [selected.name,"открыта" if doors[cell].open else "закрыта"])
	tactics.update_visibility()
	ui_invalidate()
	refresh_ui()

func reachable_routes(actor: Dictionary, steps: int) -> Dictionary:
	var routes: Dictionary={actor.cell:[actor.cell]}
	var frontier: Array[Vector2i]=[actor.cell]
	var index:=0
	while index<frontier.size():
		var cell:=frontier[index]
		index+=1
		if routes[cell].size()>steps: continue
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+d
			if not routes.has(next) and walkable(next,actor):
				var path: Array=routes[cell].duplicate()
				path.append(next)
				routes[next]=path
				frontier.append(next)
	return routes

func shoot(attacker: Dictionary,defender: Dictionary, ai: bool=false, reaction: bool=false):
	if (busy and not ai) or won or attacker.hp<=0 or defender.hp<=0: return
	if not ai and not defender.visible:
		note("Цель потеряна из виду.")
		return
	var burst: bool=not ai and tactics.mode=="burst"
	var rounds:=3 if burst else 1
	var cost:=9 if burst else (8 if aimed and attacker.team==0 and not reaction else 6)
	if reaction: cost=0
	var chance:=hit_chance(attacker,defender,not reaction)
	if reaction: chance=maxi(10,chance-10) if chance>0 else 0
	if burst: chance=maxi(10,chance-15) if chance>0 else 0
	var available: int=attacker.ap+(6 if attacker.watch and not reaction else 0)
	if available<cost or attacker.ammo<rounds:
		if not ai: note("Не хватает ОД или патронов. [R] — перезарядка.")
		return
	if chance==0:
		if not ai: note("Цель вне дальности или закрыта зданием.")
		return
	if not reaction: tactics.cancel_watch(attacker)
	busy=true
	attacker.ap-=cost
	attacker.ammo-=rounds
	clear_path()
	tactics.alert_from_shot(attacker)
	var direction: Vector3=defender.node.position-attacker.node.position
	attacker.node.rotation.y=atan2(-direction.x,-direction.z)
	for shot_index in range(rounds):
		if defender.hp<=0: break
		var start: Vector3=attacker.node.position+Vector3(0,1.15,0)+direction.normalized()*0.7
		var finish: Vector3=defender.node.position+Vector3(0,0.82 if defender.crouched else 1.1,0)
		var hit:=rng.randi_range(1,100)<=chance
		if attacker.team==0: tactics.shots+=1
		if not hit: finish+=Vector3(rng.randf_range(0.5,1.2),0.1,0.5)
		var trace: MeshInstance3D=world.rod(start,finish,0.018,"f4d699")
		var flash:=OmniLight3D.new()
		flash.position=start
		flash.light_color=Color("ffb958")
		flash.light_energy=3
		flash.omni_range=4
		add_child(flash)
		if is_instance_valid(sound): sound.play()
		refresh_ui()
		await get_tree().create_timer(0.08).timeout
		trace.queue_free()
		flash.queue_free()
		if hit:
			if attacker.team==0: tactics.hits+=1
			var damage:=rng.randi_range(17,25) if burst else rng.randi_range(28,43)
			apply_damage(defender,damage,attacker)
		else:
			effects.float_text(defender.node.position+Vector3.UP*2.3,"МИМО",Color("d9c795"))
			effects.burst_dust(finish-Vector3.UP*0.7,5,Color("a49774"))
			if attacker.visible: note("%s: промах (%d%%)." % [attacker.name,chance])
		await get_tree().create_timer(0.13 if burst else 0.22).timeout
	if not ai: busy=false
	check_outcome()
	tactics.update_visibility()
	ui_invalidate()
	refresh_ui()

func apply_damage(defender: Dictionary, damage: int, attacker: Dictionary):
	if defender.hp<=0: return
	defender.hp=maxi(0,defender.hp-damage)
	if defender.visible:
		effects.float_text(defender.node.position+Vector3.UP*2.2,"−%d" % damage,Color("f0a575"))
		note("%s → %s: −%d HP" % [attacker.name,defender.name,damage])
	if defender.hp<=0:
		if defender.team==1: tactics.kills+=1
		defender.watch=false
		defender.label.visible=false
		defender.ring.visible=false
		var tween:=create_tween()
		defender.death_tween=tween
		tween.tween_property(defender.node,"rotation:z",PI/2,0.25)
		if defender==selected:
			for u in units:
				if u.team==0 and u.hp>0:
					selected=u
					break

func end_turn():
	if busy or won: return
	busy=true
	enemy_turn=true
	tactics.mode="normal"
	clear_path()
	note("Противник меняет позиции…")
	refresh_ui()
	for enemy in units:
		if enemy.team!=1 or enemy.hp<=0: continue
		await tactics.ai_turn(enemy)
		if won: break
		await get_tree().create_timer(0.12).timeout
	turn+=1
	for u in units:
		if u.team==0:
			u.watch=false
			if u.hp>0: u.ap=MAX_AP
	busy=false
	enemy_turn=false
	tactics.update_visibility()
	ui_invalidate()
	check_outcome()
	if not won: note("Ваш ход. ОД восстановлены. [O] — прикрыть движение.")
	refresh_ui()

func check_outcome():
	if won: return
	var allies:=0
	var enemies:=0
	for u in units:
		if u.hp>0:
			if u.team==0: allies+=1
			else: enemies+=1
	var result: int=campaign.result()
	if result!=0:
		won=true
		campaign.victory=result==1
		outcome_panel=panel(Vector2(400,290),Vector2(800,320),hud)
		var title: String=("КАМПАНИЯ ЗАВЕРШЕНА" if campaign.index==3 else "МИССИЯ ВЫПОЛНЕНА") if result==1 else "МИССИЯ ПРОВАЛЕНА"
		label(title,Vector2(35,25),30,"e7cc8e",outcome_panel)
		label(campaign.TITLES[campaign.index],Vector2(35,72),20,"c5cdb1",outcome_panel)
		label("Ходов: %d  •  Выжило: %d / 3  •  Попаданий: %d\nПеред следующей миссией отряд полностью пополняется." % [turn,allies,tactics.hits],Vector2(35,114),17,"d3c19a",outcome_panel)
		if result==1 and campaign.index<3:
			button("СЛЕДУЮЩАЯ МИССИЯ →",Vector2(35,205),Vector2(355,48),campaign.next_mission,outcome_panel)
		else:
			button("ПОВТОРИТЬ МИССИЮ",Vector2(35,205),Vector2(355,48),restart,outcome_panel)
		button("НОВАЯ КАМПАНИЯ" if result==1 and campaign.index==3 else "ЗАГРУЗИТЬ  [F9]",Vector2(410,205),Vector2(350,48),campaign.new_campaign if result==1 and campaign.index==3 else quickload,outcome_panel)

func restart():
	if busy: return
	Engine.set_meta("mission_index",campaign.index)
	get_tree().reload_current_scene()

func toggle_menu():
	if cinematic:
		cinematic=false
		hud.visible=true
		refresh_ui()
		world.update_cutaways()
	if is_instance_valid(menu_panel):
		menu_panel.queue_free()
		menu_panel=null
		ui_invalidate()
		return
	if busy: return
	menu_panel=Control.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(menu_panel)
	var shade:=ColorRect.new()
	shade.color=Color(0.025,0.04,0.03,0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.add_child(shade)
	var p:=panel(Vector2(380,140),Vector2(840,690),menu_panel,"17201fff")
	label("%d / 4  •  %s" % [campaign.index+1,campaign.TITLES[campaign.index]],Vector2(32,24),24,"e6c98b",p)
	label(campaign.SECTORS[campaign.index]+"   •   БРИФИНГ",Vector2(32,72),16,"a3b296",p)
	label(campaign.BRIEFINGS[campaign.index],Vector2(32,116),17,"ddd7bf",p)
	label("F — прицел (8 ОД)       B — очередь (9 ОД, 3 патрона)\nO — прикрытие: резерв 6 ОД, один выстрел на движение врага\nR — перезарядка (5 ОД)       C — смена позы (2 ОД)\nH — аптечка, затем ЛКМ по бойцу рядом (6 ОД)\nG — граната, затем ЛКМ по земле (8 ОД). Опасна и для своих!\nПробел — конец хода.   F5 / F9 — сохранить / загрузить.\nWASD / Q/E / колесо — камера.   F2 — фото.   F12 — снимок.\nT — скрыть крыши.   V — сетка ОД.   F11 — полный экран.\nДверь: ЛКМ рядом / 2 ОД.   Бочка: ЛКМ / 6 ОД.   J — задача / 4 ОД.",Vector2(32,214),18,"c7cdb5",p)
	label("Фокс лечит на 50 HP, остальные — на 35. Прикрытие действует один ход.\nЗдоровье, патроны, снаряжение и разведка сохраняются вместе с боем.",Vector2(32,478),16,"a3b296",p)
	button("СОХРАНИТЬ  [F5]",Vector2(32,552),Vector2(242,48),quicksave,p)
	button("ЗАГРУЗИТЬ  [F9]",Vector2(286,552),Vector2(242,48),quickload,p)
	button("ПОВТОРИТЬ МИССИЮ",Vector2(540,552),Vector2(268,48),restart,p)
	button("ПРОДОЛЖИТЬ ОПЕРАЦИЮ  [ESC]",Vector2(32,612),Vector2(496,48),toggle_menu,p)
	button("НОВАЯ КАМПАНИЯ",Vector2(540,612),Vector2(268,48),campaign.new_campaign,p)

func quicksave():
	var error: String=save_system.save_game(self,save_path)
	note("Операция сохранена в saves/quicksave.json." if error=="" else error)
	if is_instance_valid(menu_panel): toggle_menu()

func quickload():
	var error: String=save_system.load_game(self,save_path)
	note("Операция загружена." if error=="" else error)
	if error=="" and is_instance_valid(menu_panel): toggle_menu()

func setup_audio():
	var audio := AudioStreamWAV.new()
	audio.format=AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate=22050
	var data := PackedByteArray()
	data.resize(6600*2)
	var audio_rng := RandomNumberGenerator.new()
	audio_rng.seed=9
	for i in range(6600):
		var t := float(i)/22050
		var value := (audio_rng.randf_range(-1,1)*0.65+sin(t*TAU*80)*0.35)*exp(-t*25)*0.4
		data.encode_s16(i*2,int(value*32767))
	audio.data=data
	sound=AudioStreamPlayer.new()
	sound.stream=audio
	sound.volume_db=-10
	add_child(sound)
	var blast:=AudioStreamWAV.new()
	blast.format=AudioStreamWAV.FORMAT_16_BITS
	blast.mix_rate=22050
	var blast_data:=PackedByteArray()
	blast_data.resize(22050*2)
	for i in range(22050):
		var t:=float(i)/22050
		var value: float=(audio_rng.randf_range(-1,1)*0.35+sin(t*TAU*45)*0.65)*exp(-t*6)*0.55
		blast_data.encode_s16(i*2,int(value*32767))
	blast.data=blast_data
	explosion_sound=AudioStreamPlayer.new()
	explosion_sound.stream=blast
	explosion_sound.volume_db=-12
	add_child(explosion_sound)

func run_tests():
	var failures: Array[String] = []
	if to_cell(to_world(Vector2i(4,5)))!=Vector2i(4,5): failures.append("grid round trip")
	if walkable(Vector2i(5,5)): failures.append("building collision")
	if walkable(Vector2i(14,10)): failures.append("cover collision")
	if walkable(units[1].cell,units[0]): failures.append("occupied cell collision")
	var p := find_path(units[0].cell,Vector2i(14,16),units[0])
	if p.size()<2: failures.append("valid route")
	for cell in p:
		if not walkable(cell,units[0]): failures.append("path through obstacle")
	if line_of_sight(Vector2i(3,5),Vector2i(14,5)): failures.append("wall blocks gunfire")
	if not line_of_sight(Vector2i(3,6),Vector2i(14,6)): failures.append("windows permit gunfire")
	if not line_of_sight(Vector2i(3,12),Vector2i(20,12)): failures.append("open road sight")
	var cover_dummy := {"cell":Vector2i(14,11)}
	if not protected_from(cover_dummy,{"cell":Vector2i(14,7)}): failures.append("directional cover")
	if protected_from(cover_dummy,{"cell":Vector2i(14,15)}): failures.append("cover wrong side")
	if failures.is_empty():
		print("UNIT TESTS PASSED: grid, collision, occupancy, pathfinding, line of sight, directional cover")
		await load("res://tactical_tests.gd").new().run(self,failures)
		await run_combat_tests(failures)
		if failures.is_empty():
			print("COMBAT TESTS PASSED; reloading scene through restart callback")
			Engine.set_meta("restart_test_pending",true)
			call_deferred("restart")
		else:
			for failure in failures: push_error("TEST FAILED: "+failure)
			get_tree().quit(1)
	else:
		for failure in failures: push_error("TEST FAILED: "+failure)
		get_tree().quit(1)

func run_combat_tests(failures: Array[String]):
	Engine.time_scale=12
	var actor := units[0]
	var route := find_path(actor.cell,Vector2i(10,16),actor)
	var movement_cost := (route.size()-1)*2
	await move_unit(actor,route)
	if actor.cell!=Vector2i(10,16) or actor.ap!=MAX_AP-movement_cost or busy: failures.append("movement and AP accounting")
	var ap_before: int = actor.ap
	toggle_crouch()
	if not actor.crouched or actor.ap!=ap_before-2: failures.append("stance/AP")
	actor.ap=MAX_AP
	var victim := units[3]
	ap_before=actor.ap
	await shoot(actor,victim)
	if actor.ap!=ap_before-6 or busy: failures.append("shooting AP / completion")
	var old_turn := turn
	await end_turn()
	if turn!=old_turn+1 or busy or enemy_turn: failures.append("enemy turn completion")
	var occupied := {}
	for u in units:
		if u.hp<=0: continue
		if occupied.has(u.cell): failures.append("overlapping actors")
		occupied[u.cell]=true
		if solid.has(u.cell) or cover.has(u.cell): failures.append("AI entered obstacle")
		if u.ap<0: failures.append("negative AP")
		if u.team==0 and u.ap!=MAX_AP: failures.append("AP refill")
	# A deterministic finishing scenario exercises damage, death and mission state.
	if actor.hp==0 and selected==actor: failures.append("dead selected actor")
	actor.hp=100
	selected=actor
	for u in units:
		if u.team==1 and u!=victim:
			u.hp=0
			u.label.visible=false
	actor.cell=Vector2i(14,12)
	actor.node.position=to_world(actor.cell)
	actor.accuracy=1000
	victim.cell=Vector2i(16,12)
	victim.node.position=to_world(victim.cell)
	victim.hp=1
	for attempt in range(4):
		if victim.hp<=0: break
		actor.ap=MAX_AP
		await shoot(actor,victim)
	if victim.hp!=0 or not won: failures.append("damage/death/victory")

func rebuild_roster():
	for unit in units: unit.node.free()
	units.clear()
	campaign.populate()
	selected=units[0]
	tactics.initialize(self)

# Stage geometry synchronously so a cross-sector save can be validated before commit.
func stage_sector(mission: int) -> Dictionary:
	var previous: Dictionary={"world":world,"explosives":explosives,"solid":solid,"cover":cover,"doors":doors,"windows":windows,"index":sector_index}
	sector_index=mission
	solid={}
	cover={}
	doors={}
	windows={}
	world=load("res://world.gd").new()
	add_child(world)
	world.build(self)
	if mission==0:
		var props: Node3D=load("res://scene_details.gd").new()
		world.add_child(props)
		props.build(world,self)
	explosives=load("res://explosives.gd").new()
	add_child(explosives)
	explosives.initialize(self)
	world.batch_static()
	return previous

func commit_sector(previous: Dictionary):
	if is_instance_valid(previous.world): previous.world.free()
	if is_instance_valid(previous.explosives): previous.explosives.free()

func rollback_sector(previous: Dictionary):
	world.free()
	explosives.free()
	world=previous.world
	explosives=previous.explosives
	solid=previous.solid
	cover=previous.cover
	doors=previous.doors
	windows=previous.windows
	sector_index=previous.index
