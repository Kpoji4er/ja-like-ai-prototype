extends RefCounted
## Deterministic multi-turn playthroughs using the same actions as the player.
const BASELINE:="res://../build/soak-baseline.json"
var failures: Array[String]=[]
var wins:=0
var losses:=0
var unfinished:=0
var turns:=0

func check(game: Node, where: String):
	var cells: Dictionary={}
	for unit in game.units:
		if unit.hp<0 or unit.hp>100 or unit.ap<0 or unit.ap>game.MAX_AP or unit.ammo<0 or unit.ammo>unit.capacity:
			failures.append(where+": resource invariant")
		if unit.hp<=0: continue
		if cells.has(unit.cell) or not game.walkable(unit.cell,unit): failures.append(where+": occupied or blocked position")
		cells[unit.cell]=true
		if unit.node.position.distance_to(game.to_world(unit.cell))>0.01: failures.append(where+": visual position mismatch")
	if game.busy or game.enemy_turn: failures.append(where+": turn did not finish")
	if not game.won and game.selected.hp<=0: failures.append(where+": selected actor is dead")

func target_for(game: Node, actor: Dictionary) -> Dictionary:
	var best: Dictionary={}
	var score:=-999.0
	for unit in game.units:
		if unit.team==0 or unit.hp<=0 or not unit.visible: continue
		var value: float=game.hit_chance(actor,unit)-unit.hp*0.12
		if value>score:
			score=value
			best=unit
	return best

func player_turn(game: Node):
	for actor in game.units:
		if actor.team!=0 or actor.hp<=0 or game.won: continue
		game.select_unit(actor)
		if game.demo_mode: await game.get_tree().create_timer(0.7).timeout
		if actor.hp<65 and actor.medkits>0: game.tactics.heal(actor)
		if actor.ammo<3 and actor.reserve>0: game.tactics.reload_weapon(actor)
		var target: Dictionary=target_for(game,actor)
		if target.is_empty() or game.hit_chance(actor,target)<55:
			var routes: Dictionary=game.reachable_routes(actor,mini(4,actor.ap/2))
			var best_score:=-9999.0
			var route: Array[Vector2i]=[]
			for cell in routes:
				var hypothetical: Dictionary=actor.duplicate()
				hypothetical.cell=cell
				var score: float=-Vector2(cell).distance_to(Vector2(19,12))
				if not target.is_empty():
					score=game.hit_chance(hypothetical,target)*0.2
					if game.protected_from(hypothetical,target): score+=4
					score-=float(routes[cell].size())*0.3
				if score>best_score:
					best_score=score
					route.assign(routes[cell])
			if route.size()>1: await game.move_unit(actor,route)
		if actor.hp<=0 or game.won: continue
		if not actor.crouched and actor.ap>=8: game.toggle_crouch()
		for shot in range(3):
			target=target_for(game,actor)
			if game.won or actor.hp<=0 or actor.ap<6 or actor.ammo<=0 or target.is_empty() or game.hit_chance(actor,target)==0: break
			await game.shoot(actor,target)
			if game.demo_mode: await game.get_tree().create_timer(0.65).timeout
		if actor.ap>=6 and not game.won: game.tactics.toggle_watch()

func run(game: Node):
	Engine.time_scale=30
	var start:=Time.get_ticks_msec()
	game.save_system.save_game(game,BASELINE)
	for seed_value in [7,19,42,96,2026,8451,9001,12121]:
		var error: String=game.save_system.load_game(game,BASELINE)
		if error!="": failures.append(error)
		game.rng.seed=seed_value
		for turn_index in range(18):
			if game.won: break
			await player_turn(game)
			check(game,"player %d / %d" % [seed_value,turn_index])
			if game.won: break
			await game.end_turn()
			turns+=1
			check(game,"AI %d / %d" % [seed_value,turn_index])
			if turn_index==2 and not game.won:
				var path:="res://../build/soak-roundtrip.json"
				game.save_system.save_game(game,path)
				var before: Dictionary=game.save_system.snapshot(game)
				error=game.save_system.load_game(game,path)
				if error!="" or game.save_system.snapshot(game)!=before: failures.append("midbattle save roundtrip: "+error)
		var living_enemies:=0
		var living_allies:=0
		for unit in game.units:
			if unit.hp>0:
				if unit.team==0: living_allies+=1
				else: living_enemies+=1
		if living_enemies==0: wins+=1
		elif living_allies==0: losses+=1
		else: unfinished+=1
		print("SOAK SEED %d: turns=%d allies=%d enemies=%d" % [seed_value,game.turn,living_allies,living_enemies])
	var report: Dictionary={"seeds":8,"enemy_turns":turns,"wins":wins,"losses":losses,"unfinished":unfinished,"seconds":(Time.get_ticks_msec()-start)/1000.0,"failures":failures}
	var file:=FileAccess.open("res://../build/soak-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("SOAK RESULTS: "+JSON.stringify(report))
	game.get_tree().quit(0 if failures.is_empty() else 1)
