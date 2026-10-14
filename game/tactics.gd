extends Node
## Turn-based equipment, visibility and reactions. All state stays in the project.
const SIGHT := 12
const RELOAD_AP := 5
const MEDKIT_AP := 6
const GRENADE_AP := 8
const WATCH_AP := 6
var game: Node
var visible_cells: Dictionary = {}
var explored: Dictionary = {}
var revealed: Dictionary = {}
var mode := "normal"
var kills := 0
var shots := 0
var hits := 0

func initialize(owner_game: Node):
	game=owner_game
	for i in range(game.units.size()):
		var u: Dictionary=game.units[i]
		var capacity: int=[30,30,20][u.index%3]
		u.merge({"id":i,"capacity":capacity,"ammo":capacity,"reserve":capacity*2,"medkits":2 if u.team==0 and u.index==1 else 1,"grenades":1 if u.team==0 else 0,"watch":false,"visible":u.team==0,"alert":Vector2i(-1,-1),"spawn":u.cell})
	update_visibility()

func can_see(observer: Dictionary, target: Dictionary) -> bool:
	return observer.hp>0 and target.hp>0 and Vector2(observer.cell).distance_to(Vector2(target.cell))<=SIGHT and game.line_of_sight(observer.cell,target.cell)

func update_visibility():
	visible_cells.clear()
	for ally in game.units:
		if ally.team!=0 or ally.hp<=0: continue
		for x in range(maxi(0,ally.cell.x-SIGHT),mini(game.W,ally.cell.x+SIGHT+1)):
			for y in range(maxi(0,ally.cell.y-SIGHT),mini(game.H,ally.cell.y+SIGHT+1)):
				var cell:=Vector2i(x,y)
				if visible_cells.has(cell) or Vector2(cell).distance_squared_to(Vector2(ally.cell))>SIGHT*SIGHT: continue
				if game.line_of_sight(ally.cell,cell):
					visible_cells[cell]=true
					explored[cell]=true
	for u in game.units:
		var was_visible: bool=u.visible
		u.visible=u.team==0 or visible_cells.has(u.cell) or int(revealed.get(u.id,-1))>=game.turn
		u.node.visible=u.visible
		if u.team==1 and u.hp>0 and u.visible and not was_visible and is_instance_valid(game.feed):
			game.note("Контакт: %s. Держитесь укрытий." % u.name)
	game.hover_cell=Vector2i(-99,-99)
	game.world.update_cutaways()
	if is_instance_valid(game.map): game.map.queue_redraw()

func alert_from_shot(shooter: Dictionary):
	if shooter.team==1: revealed[shooter.id]=game.turn+1
	for u in game.units:
		if u.team!=shooter.team and u.hp>0 and Vector2(u.cell).distance_to(Vector2(shooter.cell))<20:
			u.alert=shooter.cell
	update_visibility()

func set_mode(next_mode: String):
	if game.busy or game.won: return
	mode="normal" if mode==next_mode else next_mode
	game.aimed=false
	game.clear_path()
	game.hover_cell=Vector2i(-99,-99)
	game.refresh_ui()

func cancel_watch(unit: Dictionary, refund: bool=true):
	if unit.watch:
		unit.watch=false
		if refund: unit.ap=mini(game.MAX_AP,unit.ap+WATCH_AP)

func available_ap(unit: Dictionary) -> int:
	return unit.ap+(WATCH_AP if unit.watch else 0)

func toggle_watch():
	var u: Dictionary=game.selected
	if game.busy or game.won or u.hp<=0: return
	if u.watch:
		cancel_watch(u)
		game.note("%s: наблюдение отменено, 6 ОД возвращены." % u.name)
	elif u.ap<WATCH_AP or u.ammo<=0:
		game.note("Для реакции нужны 6 ОД и патрон в магазине.")
	else:
		u.ap-=WATCH_AP
		u.watch=true
		mode="normal"
		game.note("%s прикрывает: выстрел при движении противника." % u.name)
	game.refresh_ui()

func reload_weapon(unit: Dictionary = {}, ai: bool = false):
	if unit.is_empty(): unit=game.selected
	if (game.busy and not ai) or game.won or unit.hp<=0: return
	if unit.ammo>=unit.capacity:
		if not ai: game.note("Магазин уже полон.")
		return
	if available_ap(unit)<RELOAD_AP or unit.reserve<=0:
		if not ai: game.note("Перезарядка: нужны 5 ОД и запас патронов.")
		return
	cancel_watch(unit)
	var count: int=mini(unit.capacity-unit.ammo,unit.reserve)
	unit.ammo+=count
	unit.reserve-=count
	unit.ap-=RELOAD_AP
	game.note("%s: перезарядка, %d патронов." % [unit.name,unit.ammo])
	game.effects.float_text(unit.node.position+Vector3.UP*2.2,"ПЕРЕЗАРЯДКА",Color("dfc285"))
	game.refresh_ui()

func heal(target: Dictionary):
	var medic: Dictionary=game.selected
	if game.busy or game.won or medic.hp<=0 or target.hp<=0 or target.team!=0: return
	if Vector2(medic.cell).distance_to(Vector2(target.cell))>1.5 or not game.line_of_sight(medic.cell,target.cell):
		game.note("Для лечения подойдите вплотную к бойцу.")
		return
	if target.hp>=100:
		game.note("Боец не ранен. Аптечка не потрачена.")
		return
	if available_ap(medic)<MEDKIT_AP or medic.medkits<=0:
		game.note("Нужны аптечка и 6 ОД.")
		return
	cancel_watch(medic)
	medic.ap-=MEDKIT_AP
	medic.medkits-=1
	var restored: int=mini(100-target.hp,50 if medic.index==1 else 35)
	target.hp+=restored
	mode="normal"
	game.note("%s лечит %s: +%d HP." % [medic.name,target.name,restored])
	game.effects.float_text(target.node.position+Vector3.UP*2.2,"+%d" % restored,Color("a7d581"))
	game.refresh_ui()

func grenade_valid(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<game.W and cell.y<game.H and not game.solid.has(cell) and Vector2(game.selected.cell).distance_to(Vector2(cell))<=7 and game.line_of_sight(game.selected.cell,cell)

func throw_grenade(cell: Vector2i):
	var u: Dictionary=game.selected
	if game.busy or game.won or u.hp<=0: return
	if not grenade_valid(cell):
		game.note("Бросок до 7 клеток: нужна свободная траектория.")
		return
	if available_ap(u)<GRENADE_AP or u.grenades<=0:
		game.note("Нужны граната и 8 ОД.")
		return
	cancel_watch(u)
	u.ap-=GRENADE_AP
	u.grenades-=1
	game.busy=true
	mode="normal"
	game.clear_path()
	game.refresh_ui()
	var destination: Vector3=game.to_world(cell)+Vector3.UP*0.25
	await game.effects.grenade_arc(u.node.position+Vector3.UP*1.4,destination)
	game.effects.explosion(destination)
	game.note("%s: граната!" % u.name)
	alert_from_shot(u)
	for victim in game.units:
		if victim.hp<=0: continue
		var distance: float=Vector2(victim.cell).distance_to(Vector2(cell))
		if distance<=2.4 and game.line_of_sight(cell,victim.cell):
			var damage:=roundi(65.0-distance*17.0)
			game.apply_damage(victim,damage,u)
	game.explosives.from_grenade(cell,u)
	await get_tree().create_timer(0.5).timeout
	game.busy=false
	game.check_outcome()
	update_visibility()
	game.refresh_ui()

func trigger_reactions(mover: Dictionary):
	for observer in game.units:
		if mover.hp<=0 or game.won: break
		if observer.team==mover.team or not observer.watch or observer.hp<=0 or observer.ammo<=0: continue
		if not can_see(observer,mover): continue
		observer.watch=false
		game.note("РЕАКЦИЯ: %s открывает огонь!" % observer.name)
		await game.shoot(observer,mover,true,true)

func choose_ai_target(enemy: Dictionary) -> Dictionary:
	var chosen: Dictionary={}
	var best: float=-999
	for ally in game.units:
		if ally.team!=0 or not can_see(enemy,ally): continue
		var score: float=game.hit_chance(enemy,ally)-Vector2(enemy.cell).distance_to(Vector2(ally.cell))
		if score>best:
			best=score
			chosen=ally
	if not chosen.is_empty(): enemy.alert=chosen.cell
	return chosen

func door_toward(enemy: Dictionary,destination: Vector2i) -> Vector2i:
	for room in game.world.rooms:
		var inside: bool=room.bounds.has_point(enemy.cell)
		if inside==room.bounds.has_point(destination): continue
		for cell in game.doors:
			if room.bounds.has_point(cell) and not game.doors[cell].open: return cell
	return Vector2i(-1,-1)

func ai_turn(enemy: Dictionary):
	enemy.ap=game.MAX_AP
	enemy.watch=false
	var target: Dictionary=choose_ai_target(enemy)
	if enemy.ammo==0: reload_weapon(enemy,true)
	var destination: Vector2i=enemy.alert
	if destination.x<0:
		var patrol_points: Array[Vector2i]=[Vector2i(17,12),Vector2i(23,15),Vector2i(18,8),Vector2i(25,18)]
		destination=patrol_points[(enemy.index+game.turn)%patrol_points.size()]
	var door:=Vector2i(-1,-1)
	if target.is_empty():
		door=door_toward(enemy,destination)
		if door.x>=0:
			destination=door+Vector2i.DOWN
			for room in game.world.rooms:
				if room.bounds.has_point(door) and room.bounds.has_point(enemy.cell): destination=door+Vector2i.UP
	# One breadth-first expansion provides all reachable positions, rather than 81 searches.
	var routes: Dictionary=game.reachable_routes(enemy,mini(4,enemy.ap/2))
	var best_score: float=-9999
	var best_path: Array[Vector2i]=[]
	for cell in routes:
		var score: float=-Vector2(cell).distance_to(Vector2(destination))
		var hypothetical: Dictionary=enemy.duplicate()
		hypothetical.cell=cell
		if not target.is_empty():
			score=game.hit_chance(hypothetical,target)*0.17-Vector2(cell).distance_to(Vector2(target.cell))*0.15
			if game.protected_from(hypothetical,target): score+=5
			if Vector2(cell).distance_to(Vector2(target.cell))<3: score-=5
		else:
			if game.cover.has(cell+Vector2i.UP) or game.cover.has(cell+Vector2i.DOWN): score+=0.7
		score-=float(routes[cell].size()-1)*0.22
		if score>best_score:
			best_score=score
			best_path.assign(routes[cell])
	if best_path.size()>1: await game.move_unit(enemy,best_path,true)
	if enemy.hp<=0 or game.won: return
	if door.x>=0 and Vector2(enemy.cell).distance_to(Vector2(door))<=1.5 and enemy.ap>=2:
		enemy.ap-=2
		game.set_door_state(door,true)
		update_visibility()
		if enemy.visible: game.note("%s открывает дверь." % enemy.name)
	target=choose_ai_target(enemy)
	if not target.is_empty() and enemy.ammo>0 and enemy.ap>=6:
		await game.shoot(enemy,target,true)
	if not game.won and enemy.ap>=WATCH_AP and enemy.ammo>0:
		enemy.ap-=WATCH_AP
		enemy.watch=true
	game.refresh_ui()
