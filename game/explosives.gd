extends Node3D
var game: Node
var barrels: Dictionary={}

func initialize(owner_game: Node):
	game=owner_game
	for cell in [Vector2i(18,13),Vector2i(24,17)]:
		var root:=Node3D.new()
		add_child(root)
		root.position=game.to_world(cell)
		game.world.cylinder(Vector3(0,0.60,0),0.42,1.2,"934937",root)
		for y in [0.07,0.36,0.86,1.17]: game.world.cylinder(Vector3(0,y,0),0.435,0.05,"4b4533",root)
		game.world.cylinder(Vector3(0,1.22,0),0.40,0.035,"6f4b32",root)
		game.world.box(Vector3(0,0.61,0.426),Vector3(0.37,0.40,0.025),"d0b37c",root)
		game.world.sign_text("!",Vector3(0,0.61,0.447),47,Color("7b3b2b"),root)
		var wreck:=Node3D.new()
		add_child(wreck)
		wreck.position=game.to_world(cell)
		var drum: MeshInstance3D=game.world.cylinder(Vector3(0,0.19,0),0.43,0.35,"38382b",wreck)
		drum.rotation.z=0.18
		for i in range(5):
			var scrap: MeshInstance3D=game.world.box(Vector3(cos(i*1.7)*0.58,0.04,sin(i*1.7)*0.58),Vector3(0.3,0.05,0.17),"5e4030",wreck)
			scrap.rotation.y=i*1.7
		barrels[cell]={"node":root,"wreck":wreck,"intact":true}
		set_intact(cell,true)

func set_intact(cell: Vector2i,intact: bool):
	barrels[cell].intact=intact
	barrels[cell].node.visible=intact
	barrels[cell].wreck.visible=not intact
	if intact: game.cover[cell]=true
	else: game.cover.erase(cell)

func target_at(cell: Vector2i) -> bool:
	return barrels.has(cell) and barrels[cell].intact

func shoot(cell: Vector2i):
	var actor: Dictionary=game.selected
	if game.busy or game.won or not target_at(cell): return
	if actor.ap+(6 if actor.watch else 0)<6 or actor.ammo<1:
		game.note("Для выстрела по бочке нужны 6 ОД и патрон.")
		return
	if not game.line_of_sight(actor.cell,cell) or Vector2(actor.cell).distance_to(Vector2(cell))>19:
		game.note("Бочка вне линии огня.")
		return
	game.tactics.cancel_watch(actor)
	actor.ap-=6
	actor.ammo-=1
	game.tactics.shots+=1
	game.busy=true
	game.clear_path()
	game.refresh_ui()
	game.tactics.alert_from_shot(actor)
	var direction: Vector3=game.to_world(cell)-actor.node.position
	actor.node.rotation.y=atan2(-direction.x,-direction.z)
	var trace: MeshInstance3D=game.world.rod(actor.node.position+Vector3.UP*1.1,game.to_world(cell)+Vector3.UP*0.7,0.018,"f4d699")
	if is_instance_valid(game.sound): game.sound.play()
	await get_tree().create_timer(0.12).timeout
	trace.queue_free()
	# Large stationary targets are deliberately certain hits in this prototype.
	game.tactics.hits+=1
	detonate(cell,actor)
	await get_tree().create_timer(0.55).timeout
	game.busy=false
	game.check_outcome()
	game.tactics.update_visibility()
	game.ui_invalidate()
	game.refresh_ui()

func detonate(cell: Vector2i,actor: Dictionary):
	if not target_at(cell): return
	set_intact(cell,false)
	game.effects.explosion(game.to_world(cell)+Vector3.UP*0.5)
	game.note("Взрыв топливной бочки! Радиус — 3 клетки.")
	for victim in game.units:
		if victim.hp<=0: continue
		var distance: float=Vector2(victim.cell).distance_to(Vector2(cell))
		if distance<=3 and game.line_of_sight(cell,victim.cell): game.apply_damage(victim,roundi(90-distance*19),actor)
	for other in barrels:
		if target_at(other) and Vector2(other).distance_to(Vector2(cell))<=3 and game.line_of_sight(cell,other): detonate(other,actor)

func from_grenade(cell: Vector2i,actor: Dictionary):
	for other in barrels:
		if target_at(other) and Vector2(other).distance_to(Vector2(cell))<=2.4 and game.line_of_sight(cell,other): detonate(other,actor)
