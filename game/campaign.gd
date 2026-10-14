extends Node3D
const SECTORS=["A9 / БЛОКПОСТ ОМЕРТЫ","B9 / ДЕРЕВНЯ САН-МИГЕЛЬ","B10 / РАДИОСТАНЦИЯ","C10 / ШТАБ ГАРНИЗОНА"]
const TITLES=["ТИХИЙ ЭФИР","ЖИВОЙ СВИДЕТЕЛЬ","ПОСЛЕДНЯЯ ЧАСТОТА","ОБЕЗГЛАВИТЬ ГАРНИЗОН"]
const GOALS=["Устранить патруль: 4 противника","Забрать связного в клинике и вывести на запад","Защитить передатчик в течение 5 ходов","Отключить 2 узла и уничтожить гарнизон"]
const BRIEFINGS=[
	"Патруль перекрыл дорогу. Устраните четырёх противников.\nИспользуйте ящики, машины и мешки с песком как укрытия.\nПосле победы откроется следующая операция.",
	"Шесть охранников удерживают связного в клинике. Войдите через дверь.\nПодойдите к связному и нажмите J (4 ОД). Он следует за этим бойцом.\nДоведите его до зелёной зоны на западе. Зачистка не обязательна.",
	"Восемь солдат атакуют с двух направлений. Передатчик должен выстоять.\nПродержитесь пять ходов противника: не отдавайте площадку врагу.\nВраги обстреливают передатчик с близкого расстояния. Его потеря — провал.",
	"Десять опытных бойцов прикрывают штаб и два узла управления.\nПодойдите к каждому золотому маркеру и нажмите J (4 ОД).\nОтключите оба узла и уничтожьте весь гарнизон. Это финал кампании."
]
const STARTS=[ [Vector2i(6,16),Vector2i(8,15),Vector2i(5,14)], [Vector2i(4,12),Vector2i(4,13),Vector2i(5,12)], [Vector2i(9,16),Vector2i(11,16),Vector2i(10,17)], [Vector2i(4,21),Vector2i(5,21),Vector2i(5,20)] ]
const ENEMIES=[
	[Vector2i(19,12),Vector2i(23,15),Vector2i(18,8),Vector2i(25,18)],
	[Vector2i(19,11),Vector2i(25,11),Vector2i(23,7),Vector2i(25,5),Vector2i(18,16),Vector2i(29,13)],
	[Vector2i(16,12),Vector2i(20,12),Vector2i(24,14),Vector2i(26,20),Vector2i(17,23),Vector2i(14,24),Vector2i(3,23),Vector2i(2,18)],
	[Vector2i(16,20),Vector2i(19,18),Vector2i(22,21),Vector2i(28,22),Vector2i(18,12),Vector2i(22,12),Vector2i(29,12),Vector2i(18,8),Vector2i(23,7),Vector2i(25,5)]
]
var game: Node
var index:=0
var escort:=-1
var civilian_cell:=Vector2i(25,6)
var relay_hp:=150
var switches: Array[bool]=[false,false]
var victory:=false
var marker_root: Node3D
var civilian: Node3D
var civilian_label: Label3D
var terminal_labels: Array[Label3D]=[]
var civilian_ring: MeshInstance3D
var relay_cell:=Vector2i(10,16)
var extraction:=Vector2i(3,13)
var terminals: Array[Vector2i]=[Vector2i(17,9),Vector2i(25,6)]
var progress_path:="res://../saves/campaign.json"

func initialize(owner_game: Node):
	game=owner_game
	var automated:=not OS.get_cmdline_user_args().is_empty()
	index=int(Engine.get_meta("mission_index",0))
	if not automated and not Engine.has_meta("mission_index") and FileAccess.file_exists(progress_path):
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(progress_path))==OK and parser.data is Dictionary:
			var value: Variant=parser.data.get("mission")
			if (value is int or value is float) and value==floorf(value) and value>=0 and value<4: index=int(value)
	index=clampi(index,0,3)

func populate():
	for i in range(3): game.add_unit(["ИВАН","ФОКС","АЙС"][i],0,STARTS[index][i],i,[88,80,85][i])
	for i in range(ENEMIES[index].size()):
		game.add_unit(["ПАТРУЛЬ","СТРЕЛОК","СЕРЖАНТ","СОЛДАТ"][i%4],1,ENEMIES[index][i],i,([68,72,78,65][i] if index==0 else 68+index*4+i%3))

func setup_visuals():
	if is_instance_valid(marker_root): marker_root.free()
	terminal_labels.clear()
	marker_root=Node3D.new()
	add_child(marker_root)
	if index==1:
		civilian=Node3D.new()
		marker_root.add_child(civilian)
		# Unarmed local contact: cream shirt, dark trousers, no military kit.
		game.world.ball(Vector3(0,1.1,0),Vector3(0.29,0.36,0.18),"c7b991",civilian)
		game.world.ball(Vector3(0,1.66,0),Vector3(0.17,0.21,0.16),"ab8062",civilian)
		game.world.ball(Vector3(0,1.8,0.025),Vector3(0.18,0.09,0.17),"40372e",civilian)
		for side in [-1,1]:
			game.world.rod(Vector3(side*0.14,0.85,0),Vector3(side*0.16,0.12,0),0.12,"515047",civilian)
			game.world.ball(Vector3(side*0.16,0.1,-0.06),Vector3(0.12,0.1,0.2),"34382e",civilian)
			game.world.rod(Vector3(side*0.31,1.32,0),Vector3(side*0.34,0.87,-0.04),0.075,"ab8062",civilian)
		civilian_label=mark(civilian_cell,"СВЯЗНОЙ · J",Color("f4d683"))
		civilian_ring=marker_root.get_child(marker_root.get_child_count()-2)
		mark(extraction,"ЭВАКУАЦИЯ",Color("7cdd99"),2.4)
	elif index==2:
		var p: Vector3=game.to_world(relay_cell)
		game.world.box(p+Vector3.UP*0.75,Vector3(0.8,1.5,0.55),"607b68",marker_root)
		game.world.rod(p+Vector3.UP,p+Vector3.UP*4.5,0.045,"9d9e81",marker_root)
		game.world.rod(p+Vector3(-0.8,4,0),p+Vector3(0.8,4,0),0.035,"9d9e81",marker_root)
		mark(relay_cell,"ПЕРЕДАТЧИК",Color("7cdd99"),1.3)
	elif index==3:
		for i in range(2):
			var p: Vector3=game.to_world(terminals[i])
			game.world.box(p+Vector3.UP*0.6,Vector3(0.6,1.2,0.4),"596d5c",marker_root)
			terminal_labels.append(mark(terminals[i],"УЗЕЛ %d · J" % (i+1),Color("f4d683")))
	update_visuals()

func mark(cell: Vector2i,text: String,color: Color,radius: float=0.8) -> Label3D:
	var ring: MeshInstance3D=game.ring_mesh(radius,color)
	marker_root.add_child(ring)
	ring.position=game.to_world(cell)+Vector3.UP*0.09
	var label: Label3D=game.world.sign_text(text,game.to_world(cell)+Vector3.UP*2.9,36,color,marker_root)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size=7
	label.outline_modulate=Color("15251b")
	return label

func update_visuals():
	if index==1 and is_instance_valid(civilian):
		civilian.position=game.to_world(civilian_cell)+Vector3(0.45,0,0.35)
		civilian_label.position=game.to_world(civilian_cell)+Vector3.UP*2.9
		civilian_ring.position=game.to_world(civilian_cell)+Vector3.UP*0.09
	if index==3:
		for i in range(terminal_labels.size()):
			terminal_labels[i].text="УЗЕЛ %d · %s" % [i+1,"ОТКЛЮЧЁН" if switches[i] else "J"]
			terminal_labels[i].modulate=Color("7cdd99") if switches[i] else Color("f4d683")

func interact():
	if game.busy or game.won: return
	var actor: Dictionary=game.selected
	var goal:=civilian_cell if index==1 else Vector2i(-99,-99)
	var terminal:=-1
	if index==3:
		for i in range(2):
			if not switches[i] and Vector2(actor.cell).distance_to(Vector2(terminals[i]))<=1.5:
				terminal=i
				goal=terminals[i]
	if index not in [1,3] or Vector2(actor.cell).distance_to(Vector2(goal))>1.5 or not game.line_of_sight(actor.cell,goal):
		game.note("Подойдите к золотому маркеру задачи. Взаимодействие — J.")
		return
	if index==1 and escort==actor.id:
		game.note("Связной уже следует за выбранным бойцом. Ведите его в зону эвакуации.")
		return
	if actor.ap<4:
		game.note("Для задачи нужны 4 ОД.")
		return
	actor.ap-=4
	if index==1:
		escort=actor.id
		game.note("Связной следует за %s. Выход — зелёная зона на западе." % actor.name)
	else:
		switches[terminal]=true
		game.note("Узел %d отключён." % (terminal+1))
	update_visuals()
	game.check_outcome()
	game.refresh_ui()

func moved(actor: Dictionary):
	if index==1 and actor.id==escort and actor.hp>0: civilian_cell=actor.cell
	update_visuals()

func result() -> int:
	var allies:=0
	var enemies:=0
	for unit in game.units:
		if unit.hp>0:
			if unit.team==0: allies+=1
			else: enemies+=1
	if allies==0 or (index==2 and relay_hp<=0): return -1
	match index:
		0: return 1 if enemies==0 else 0
		1: return 1 if escort>=0 and game.units[escort].hp>0 and Vector2(civilian_cell).distance_to(Vector2(extraction))<=1.5 else 0
		2: return 1 if game.turn>=6 else 0
		3: return 1 if enemies==0 and switches[0] and switches[1] else 0
	return 0

func objective_text() -> String:
	if index==1: return "Связной: %s  •  J — сопровождение" % ("следует за "+game.units[escort].name if escort>=0 and game.units[escort].hp>0 else "ожидает в отмеченной точке")
	if index==2: return "Передатчик: %d HP  •  Выстояли: %d / 5" % [relay_hp,mini(5,game.turn-1)]
	if index==3: return "Узлы: %d / 2  •  Гарнизон: %d / 10" % [int(switches[0])+int(switches[1]),game.tactics.kills]
	return "Контактов: %d  •  Устранено: %d / 4" % [visible_enemies(),game.tactics.kills]

func visible_enemies() -> int:
	var count:=0
	for unit in game.units:
		if unit.team==1 and unit.hp>0 and unit.visible: count+=1
	return count

func next_mission():
	if game.busy or not game.won or not victory: return
	if index==3: return
	Engine.set_meta("mission_index",index+1)
	write_checkpoint(index+1)
	game.get_tree().reload_current_scene()

func new_campaign():
	if game.busy: return
	Engine.set_meta("mission_index",0)
	write_checkpoint(0)
	game.get_tree().reload_current_scene()

func write_checkpoint(mission: int):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(progress_path).get_base_dir())
	var file:=FileAccess.open(progress_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"mission":mission}))
	else: game.note("Не удалось записать контрольную точку кампании.")

func state() -> Dictionary:
	return {"mission":index,"escort":escort,"civilian":[civilian_cell.x,civilian_cell.y],"relay_hp":relay_hp,"switches":switches.duplicate()}

func restore(data: Dictionary):
	index=int(data.mission)
	escort=int(data.escort)
	civilian_cell=Vector2i(int(data.civilian[0]),int(data.civilian[1]))
	relay_hp=int(data.relay_hp)
	switches.assign(data.switches)
	victory=false
	Engine.set_meta("mission_index",index)
	setup_visuals()

func attack_relay(enemy: Dictionary) -> bool:
	if index!=2 or enemy.ap<6 or enemy.ammo<1: return false
	if Vector2(enemy.cell).distance_to(Vector2(relay_cell))>4 or not game.line_of_sight(enemy.cell,relay_cell): return false
	enemy.ap-=6
	enemy.ammo-=1
	var damage: int=game.rng.randi_range(10,14)
	relay_hp=maxi(0,relay_hp-damage)
	game.tactics.alert_from_shot(enemy)
	var start: Vector3=enemy.node.position+Vector3.UP*1.2
	var finish: Vector3=game.to_world(relay_cell)+Vector3.UP
	var direction: Vector3=finish-start
	enemy.node.rotation.y=atan2(-direction.x,-direction.z)
	var trace: MeshInstance3D=game.world.rod(start,finish,0.018,"f4d699")
	var tween:=trace.create_tween()
	tween.tween_interval(0.14)
	tween.tween_callback(trace.queue_free)
	if is_instance_valid(game.sound): game.sound.play()
	game.effects.float_text(game.to_world(relay_cell)+Vector3.UP*2.2,"−%d" % damage,Color("ed9976"))
	game.note("Враг обстреливает передатчик: −%d HP, осталось %d." % [damage,relay_hp])
	game.check_outcome()
	return true
