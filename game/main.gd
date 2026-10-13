extends Node3D

const W := 32
const H := 26
const C := 1.8
const MAX_AP := 20
var solid := {}
var cover := {}
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
var feed: Label
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
var sound: AudioStreamPlayer

func to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x-(W-1)*0.5)*C,0,(cell.y-(H-1)*0.5)*C)

func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x/C+(W-1)*0.5),roundi(p.z/C+(H-1)*0.5))

func _ready():
	rng.seed = 2026
	test_mode = "--test" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	if capture_mode: get_viewport().gui_disable_input=true
	setup_environment()
	world = load("res://world.gd").new()
	add_child(world)
	world.build(self)
	add_unit("ИВАН",0,Vector2i(6,16),0,88)
	add_unit("ФОКС",0,Vector2i(8,15),1,80)
	add_unit("АЙС",0,Vector2i(5,14),2,85)
	add_unit("ПАТРУЛЬ",1,Vector2i(19,12),0,68)
	add_unit("СТРЕЛОК",1,Vector2i(23,15),1,72)
	add_unit("СЕРЖАНТ",1,Vector2i(18,8),2,78)
	add_unit("СОЛДАТ",1,Vector2i(25,18),3,65)
	selected = units[0]
	cursor = ring_mesh(0.7,Color("dbbf75"))
	add_child(cursor)
	cursor.visible = false
	setup_ui()
	if not test_mode: setup_audio()
	note("Высадка завершена. Зачистите дорогу через Омерту.")
	refresh_ui()
	if test_mode:
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
	elif "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/preview.png"))
		print("SCREENSHOT_SAVED")
		get_tree().quit()

func setup_environment():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a6ac95")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7c2bb")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.0
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
	label("ТАКТИЧЕСКИЙ ПРОТОТИП",Vector2(117,38),12,"8f9b88",top)
	label("A9  /  ОМЕРТА",Vector2(530,12),21,"e2d9bb",top)
	label("СЕВЕРНЫЙ СЕКТОР    •    17:42",Vector2(530,40),12,"a8ae97",top)
	turn_label = label("ХОД 01  /  ВАШ ОТРЯД",Vector2(1125,22),19,"d8be80",top)
	var mission := panel(Vector2(24,110),Vector2(346,94),root,"19231cdb")
	label("ОПЕРАЦИЯ «ВОЗВРАЩЕНИЕ»",Vector2(16,12),16,"dfc38a",mission)
	label("Зачистить дорогу через Омерту",Vector2(16,40),17,"e3dfc9",mission)
	status = label("Противников в секторе: 4",Vector2(16,66),13,"a4b096",mission)
	var minimap_panel := panel(Vector2(1332,110),Vector2(244,220),root)
	label("РАЗВЕДКА  /  A9",Vector2(14,9),13,"c5b88e",minimap_panel)
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
	detail = label("",Vector2(690,18),19,"e3d8b8",bottom)
	hint = label("",Vector2(690,53),14,"aeb89f",bottom)
	button("ПРИЦЕЛ  [F]",Vector2(690,96),Vector2(170,48),toggle_aim,bottom)
	button("ПРИСЕСТЬ  [C]",Vector2(872,96),Vector2(178,48),toggle_crouch,bottom)
	button("КОНЕЦ ХОДА  [ПРОБЕЛ]",Vector2(1178,94),Vector2(353,50),end_turn,bottom)
	button("НОВАЯ ОПЕРАЦИЯ",Vector2(1178,36),Vector2(353,43),restart,bottom)
	var feed_panel := panel(Vector2(24,668),Vector2(490,124),root,"19231cd9")
	label("РАДИО  /  ТАКТИЧЕСКИЙ КАНАЛ",Vector2(14,8),12,"b5a77b",feed_panel)
	feed = label("",Vector2(14,34),14,"d2d3b7",feed_panel)
	var help_bar := panel(Vector2(529,757),Vector2(1047,36),root,"19231ce0")
	label("ЛКМ: идти / огонь   •   WASD: камера   •   Q/E: поворот   •   Колесо: масштаб   •   TAB: боец   •   F2: фото",Vector2(14,8),13,"e1dcc6",help_bar)

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
	clear_path()
	refresh_ui()

func refresh_ui():
	if not is_instance_valid(status): return
	var enemies := 0
	for u in units:
		if u.team==1 and u.hp>0: enemies+=1
		u.ring.visible = u.hp>0
		u.ring.scale = Vector3.ONE*(1.23 if u==selected else 0.82)
		if u.hp>0: u.label.text = u.name+"\n"+str(u.hp)+" HP"
	status.text = "Противников в секторе: %d" % enemies
	turn_label.text = "ХОД %02d  /  %s" % [turn,"ПРОТИВНИК" if enemy_turn else "ВАШ ОТРЯД"]
	for i in range(cards.size()):
		var u := units[i]
		card_labels[i].text = "[%d] %s%s\nHP %d / 100\nОД %02d / 20\n%s" % [i+1,u.name," ◂" if u==selected else "",u.hp,u.ap,"ВЫБЫЛ" if u.hp<=0 else ("СИДИТ" if u.crouched else "ГОТОВ")]
		health_bars[i].size.x=113.0*u.hp/100.0
		cards[i].add_theme_stylebox_override("normal",style("364336ee" if u==selected else "25302bee","ccb478" if u==selected else "5b604b",2 if u==selected else 1))
	detail.text = "%s   /   %s   /   ОД %d" % [selected.name,["АК-74","MP5","M14"][selected.index],selected.ap]
	hint.text = "Прицельный огонь: 8 ОД" if aimed else "Выстрел: 6 ОД  •  Шаг: 2 ОД  •  Присесть: 2 ОД"
	map.queue_redraw()

func note(text: String):
	log_lines.append(text)
	if log_lines.size()>4: log_lines.pop_front()
	if is_instance_valid(feed): feed.text = "\n".join(log_lines)
	print(text)

func _process(delta: float):
	if capture_mode: return
	time += delta
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
	if not busy: update_hover()

func _unhandled_input(event: InputEvent):
	if capture_mode: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom = maxf(18,zoom-2.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(68,zoom+2.5)
		if event.button_index==MOUSE_BUTTON_RIGHT:
			aimed=false
			refresh_ui()
		if event.button_index==MOUSE_BUTTON_LEFT and not busy and not won:
			if not hover_unit.is_empty():
				if hover_unit.team==0: select_unit(hover_unit)
				else: shoot(selected,hover_unit)
			elif current_path.size()>1: move_unit(selected,current_path.duplicate())
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: end_turn()
			KEY_C: toggle_crouch()
			KEY_F: toggle_aim()
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
				for u in units:
					u.label.visible = not cinematic and u.hp>0
					u.ring.visible = not cinematic and u.hp>0
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
		if u.hp<=0: continue
		var screen := camera.unproject_position(u.node.position+Vector3.UP)
		var distance := mouse.distance_to(screen)
		if distance<best:
			best=distance
			target=u
	if cell==hover_cell and target==hover_unit: return
	hover_cell=cell
	hover_unit=target
	clear_path()
	if not target.is_empty():
		cursor.position=to_world(target.cell)+Vector3.UP*0.08
		cursor.visible=true
		if target.team==1:
			hint.text="%s: %d%%  •  %s" % [target.name,hit_chance(selected,target),"НЕТ ЛИНИИ ОГНЯ" if not line_of_sight(selected.cell,target.cell) else ("УКРЫТИЕ" if protected_from(target,selected) else "ОТКРЫТ")]
		return
	if not walkable(cell,selected): return
	current_path=find_path(selected.cell,cell,selected)
	var cost := (current_path.size()-1)*2
	if current_path.size()<2: return
	hint.text="Перемещение: %d ОД%s" % [cost,"  •  не хватает ОД" if cost>selected.ap else "  •  ЛКМ — идти"]
	for i in range(1,mini(current_path.size(),32)):
		var marker := ring_mesh(0.12,Color("d6c084") if i*2<=selected.ap else Color("a85843"))
		add_child(marker)
		marker.position=to_world(current_path[i])+Vector3.UP*0.04
		path_nodes.append(marker)
	cursor.position=to_world(cell)+Vector3.UP*0.06
	cursor.visible=true

func clear_path():
	for marker in path_nodes: marker.queue_free()
	path_nodes.clear()
	current_path.clear()
	if is_instance_valid(cursor): cursor.visible=false

func line_of_sight(a: Vector2i,b: Vector2i) -> bool:
	var delta_v := Vector2(b-a)
	var steps := int(maxf(absf(delta_v.x),absf(delta_v.y))*4)
	for i in range(1,steps):
		var p := Vector2(a).lerp(Vector2(b),float(i)/steps)
		if solid.has(Vector2i(roundi(p.x),roundi(p.y))): return false
	return true

func protected_from(defender: Dictionary, attacker: Dictionary) -> bool:
	var toward := Vector2(attacker.cell-defender.cell).normalized()
	for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if Vector2(d).dot(toward)>0.2 and cover.has(defender.cell+d): return true
	return false

func hit_chance(attacker: Dictionary,defender: Dictionary) -> int:
	if not line_of_sight(attacker.cell,defender.cell): return 0
	var distance := Vector2(attacker.cell).distance_to(Vector2(defender.cell))
	if distance>19: return 0
	var chance: float = attacker.accuracy-maxf(0,distance-4)*3
	if protected_from(defender,attacker): chance-=28
	if defender.crouched: chance-=12
	if attacker.crouched: chance+=9
	if aimed and attacker.team==0: chance+=18
	return clampi(roundi(chance),10,95)

func move_unit(unit: Dictionary,path: Array[Vector2i], ai: bool = false):
	var cost := (path.size()-1)*2
	if path.size()<2 or cost>unit.ap or unit.hp<=0: return
	if busy and not ai: return
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
		map.queue_redraw()
	unit.node.get_node("LegL").rotation.x=0
	unit.node.get_node("LegR").rotation.x=0
	if not ai:
		busy=false
		hover_cell=Vector2i(-99,-99)
	refresh_ui()

func toggle_aim():
	if busy or won: return
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

func shoot(attacker: Dictionary,defender: Dictionary, ai: bool = false):
	if (busy and not ai) or won or attacker.hp<=0 or defender.hp<=0: return
	var cost := 8 if aimed and attacker.team==0 else 6
	var chance := hit_chance(attacker,defender)
	if attacker.ap<cost:
		if not ai: note("Недостаточно очков действия для выстрела.")
		return
	if chance==0:
		if not ai: note("Цель вне дальности или закрыта зданием.")
		return
	busy=true
	attacker.ap-=cost
	clear_path()
	var direction: Vector3 = defender.node.position-attacker.node.position
	attacker.node.rotation.y=atan2(-direction.x,-direction.z)
	var start: Vector3 = attacker.node.position+Vector3(0,1.15,0)+direction.normalized()*0.7
	var finish: Vector3 = defender.node.position+Vector3(0,1.1,0)
	var hit := rng.randi_range(1,100)<=chance
	if not hit: finish+=Vector3(rng.randf_range(0.5,1.2),0.1,0.5)
	var trace: MeshInstance3D = world.rod(start,finish,0.023,"f4d699")
	var flash := OmniLight3D.new()
	flash.position=start
	flash.light_color=Color("ffb958")
	flash.light_energy=3
	flash.omni_range=4
	add_child(flash)
	if is_instance_valid(sound): sound.play()
	refresh_ui()
	await get_tree().create_timer(0.09).timeout
	trace.queue_free()
	flash.queue_free()
	if hit:
		var damage := rng.randi_range(28,43)
		defender.hp=maxi(0,defender.hp-damage)
		note("%s → %s: −%d HP" % [attacker.name,defender.name,damage])
		if defender.hp<=0:
			defender.label.visible=false
			defender.ring.visible=false
			var tween := create_tween()
			tween.tween_property(defender.node,"rotation:z",PI/2,0.25)
			if defender==selected:
				for u in units:
					if u.team==0 and u.hp>0:
						selected=u
						break
	else: note("%s: промах (%d%%)." % [attacker.name,chance])
	await get_tree().create_timer(0.22).timeout
	if not ai: busy=false
	check_outcome()
	hover_cell=Vector2i(-99,-99)
	refresh_ui()

func end_turn():
	if busy or won: return
	busy=true
	enemy_turn=true
	clear_path()
	note("Противник меняет позиции…")
	refresh_ui()
	for enemy in units:
		if enemy.team!=1 or enemy.hp<=0: continue
		enemy.ap=MAX_AP
		var target: Dictionary = {}
		var distance := 999.0
		for ally in units:
			if ally.team!=0 or ally.hp<=0: continue
			var d := Vector2(enemy.cell).distance_to(Vector2(ally.cell))
			if d<distance:
				target=ally
				distance=d
		if target.is_empty(): break
		if hit_chance(enemy,target)<45:
			var best_path: Array[Vector2i] = []
			var best_score := -999.0
			for dx in range(-4,5):
				for dy in range(-4,5):
					var cell: Vector2i = enemy.cell+Vector2i(dx,dy)
					if not walkable(cell,enemy): continue
					var p := find_path(enemy.cell,cell,enemy)
					if p.size()<2 or p.size()>5: continue
					var score := -Vector2(cell).distance_to(Vector2(target.cell))
					if line_of_sight(cell,target.cell): score+=8
					var hypothetical := enemy.duplicate()
					hypothetical.cell=cell
					if protected_from(hypothetical,target): score+=4
					if score>best_score:
						best_score=score
						best_path=p
			if not best_path.is_empty(): await move_unit(enemy,best_path,true)
		if target.hp>0 and hit_chance(enemy,target)>0: await shoot(enemy,target,true)
		if won: break
		await get_tree().create_timer(0.15).timeout
	turn+=1
	for u in units:
		if u.team==0 and u.hp>0: u.ap=MAX_AP
	busy=false
	enemy_turn=false
	hover_cell=Vector2i(-99,-99)
	if not won: note("Ваш ход. Очки действия восстановлены.")
	refresh_ui()

func check_outcome():
	var allies := 0
	var enemies := 0
	for u in units:
		if u.hp>0:
			if u.team==0: allies+=1
			else: enemies+=1
	if enemies==0 or allies==0:
		won=true
		var p := panel(Vector2(475,340),Vector2(650,190),hud)
		label("СЕКТОР ОСВОБОЖДЁН" if enemies==0 else "ОПЕРАЦИЯ ПРЕРВАНА",Vector2(35,25),30,"e7cc8e",p)
		label("Омерта под контролем отряда A.I.M." if enemies==0 else "Отряд потерян. Попробуйте другой маршрут.",Vector2(35,80),20,"c5cdb1",p)
		button("НОВАЯ ОПЕРАЦИЯ",Vector2(35,125),Vector2(580,45),restart,p)

func restart():
	if busy: return
	get_tree().reload_current_scene()

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

func run_tests():
	var failures: Array[String] = []
	if to_cell(to_world(Vector2i(4,5)))!=Vector2i(4,5): failures.append("grid round trip")
	if walkable(Vector2i(6,5)): failures.append("building collision")
	if walkable(Vector2i(14,10)): failures.append("cover collision")
	if walkable(units[1].cell,units[0]): failures.append("occupied cell collision")
	var p := find_path(units[0].cell,Vector2i(14,16),units[0])
	if p.size()<2: failures.append("valid route")
	for cell in p:
		if not walkable(cell,units[0]): failures.append("path through obstacle")
	if line_of_sight(Vector2i(3,6),Vector2i(14,6)): failures.append("wall blocks gunfire")
	if not line_of_sight(Vector2i(3,12),Vector2i(20,12)): failures.append("open road sight")
	var cover_dummy := {"cell":Vector2i(14,11)}
	if not protected_from(cover_dummy,{"cell":Vector2i(14,7)}): failures.append("directional cover")
	if protected_from(cover_dummy,{"cell":Vector2i(14,15)}): failures.append("cover wrong side")
	if failures.is_empty():
		print("UNIT TESTS PASSED: grid, collision, occupancy, pathfinding, line of sight, directional cover")
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
