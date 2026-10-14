extends RefCounted
var failures: Array[String]=[]

func expect(condition: bool, message: String):
	if not condition:
		failures.append(message)
		push_error("CAMPAIGN: "+message)

func reset(game: Node, mission: int):
	if game.sector_index!=mission: game.commit_sector(game.stage_sector(mission))
	game.campaign.index=mission
	game.campaign.restore({"mission":mission,"escort":-1,"civilian":[25,6],"relay_hp":150,"switches":[false,false]})
	game.rebuild_roster()
	game.turn=1
	game.won=false
	game.busy=false
	game.tactics.kills=0
	game.tactics.explored.clear()
	game.tactics.revealed.clear()
	for cell in game.doors: game.set_door_state(cell,false)
	game.tactics.update_visibility()
	if is_instance_valid(game.outcome_panel): game.outcome_panel.free()
	game.outcome_panel=null
	game.refresh_ui()

func place(game: Node, unit: Dictionary, cell: Vector2i):
	unit.cell=cell
	unit.node.position=game.to_world(cell)

func run(game: Node):
	game.campaign.progress_path="res://../build/campaign-checkpoint.json"
	if Engine.has_meta("campaign_transition"):
		failures.assign(Engine.get_meta("campaign_failures",[]))
		var expected: int=Engine.get_meta("campaign_transition")
		expect(game.campaign.index==expected,"scene transition advances exactly one mission")
		expect(game.units.size()==7+expected*2,"transition populates expected roster")
		for unit in game.units: expect(unit.hp==100 and unit.ap==20 and unit.ammo==unit.capacity,"resupply before next mission")
		if expected<3:
			Engine.set_meta("campaign_failures",failures)
			game.won=true
			game.campaign.victory=true
			Engine.set_meta("campaign_transition",expected+1)
			game.campaign.next_mission()
		else:
			game.won=true
			game.campaign.victory=true
			game.campaign.next_mission()
			expect(game.campaign.index==3,"final mission does not advance past campaign")
			finish(game)
		return
	var signatures: Dictionary={}
	for mission in range(4):
		reset(game,mission)
		var signature: String=str(game.solid.keys())+str(game.cover.keys())
		expect(not signatures.has(signature),"every sector has a distinct collision layout")
		signatures[signature]=true
		expect(game.units.size()==7+mission*2,"enemy counts 4/6/8/10")
		var occupied: Dictionary={}
		for unit in game.units:
			expect(not game.solid.has(unit.cell) and not game.cover.has(unit.cell) and not occupied.has(unit.cell),"legal spawn mission %d cell %s" % [mission+1,unit.cell])
			occupied[unit.cell]=true
		expect(game.save_system.validate(game.save_system.snapshot(game),game)=="","initial snapshot valid mission %d" % (mission+1))
		for cell in game.doors: game.set_door_state(cell,true)
		var routes: Dictionary=game.reachable_routes(game.units[0],1000)
		var goals: Array[Vector2i]=[]
		if mission==1: goals.assign([game.campaign.civilian_cell,game.campaign.extraction])
		if mission==2: goals.append(game.campaign.relay_cell)
		if mission==3: goals.assign(game.campaign.terminals)
		for goal in goals:
			var accessible:=false
			for cell in routes:
				if Vector2(cell).distance_to(Vector2(goal))<=1.5 and game.line_of_sight(cell,goal): accessible=true
			expect(accessible,"objective accessible in sector %d" % mission)
		for unit in game.units:
			if unit.team==1: unit.hp=0
		expect(game.campaign.result()==(1 if mission==0 else 0),"only patrol won by kills alone")
	reset(game,1)
	var actor: Dictionary=game.units[0]
	game.campaign.interact()
	expect(game.campaign.escort==-1 and actor.ap==20,"remote rescue blocked")
	place(game,actor,Vector2i(24,6))
	actor.ap=3
	game.campaign.interact()
	expect(game.campaign.escort==-1,"rescue requires 4 AP")
	actor.ap=20
	game.campaign.interact()
	expect(game.campaign.escort==0 and actor.ap==16,"rescue binds escort and spends AP")
	var route: Array[Vector2i]=[Vector2i(24,6),Vector2i(24,7)]
	await game.move_unit(actor,route,false)
	expect(game.campaign.civilian_cell==Vector2i(24,7),"civilian follows actual movement")
	var path: String="res://../build/campaign-save.json"
	expect(game.save_system.save_game(game,path)=="","save rescue")
	reset(game,3)
	var old_world: Node=game.world
	var broken:=JSON.new()
	broken.parse(FileAccess.get_file_as_string(path))
	broken.data.units[0].hp=-1
	var file:=FileAccess.open("res://../build/campaign-invalid.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(broken.data))
	file.close()
	expect(game.save_system.load_game(game,"res://../build/campaign-invalid.json")!="" and game.world==old_world and game.sector_index==3 and game.units.size()==13,"invalid cross-sector save rolls back geometry and roster")
	expect(game.save_system.load_game(game,path)=="","cross-mission load")
	expect(game.campaign.index==1 and game.units.size()==9 and game.campaign.escort==0 and game.campaign.civilian_cell==Vector2i(24,7),"cross-mission roster/objective restored")
	var invalid: Dictionary=game.save_system.snapshot(game)
	invalid.campaign.mission=4
	expect(game.save_system.validate(invalid,game)!="" and game.campaign.index==1,"corrupt campaign rejected without mutation")
	place(game,game.units[0],game.campaign.extraction)
	game.campaign.moved(game.units[0])
	expect(game.campaign.result()==1,"extraction wins with hostiles alive")
	game.units[0].hp=0
	expect(game.campaign.result()==0,"dead escort cannot extract")
	reset(game,2)
	var enemy: Dictionary=game.units[3]
	place(game,enemy,Vector2i(12,16))
	var hp: int=game.campaign.relay_hp
	await game.tactics.ai_turn(enemy)
	expect(game.campaign.relay_hp<hp,"AI actively attacks relay")
	game.busy=false # ai_turn is normally wrapped by end_turn, which releases this lock.
	var relay_saved: int=game.campaign.relay_hp
	expect(game.save_system.save_game(game,path)=="","save damaged relay")
	game.campaign.relay_hp=1
	expect(game.save_system.load_game(game,path)=="" and game.campaign.relay_hp==relay_saved,"relay damage survives reload")
	game.turn=5
	expect(game.campaign.result()==0,"four defensive rounds insufficient")
	game.turn=6
	expect(game.campaign.result()==1,"five defensive rounds win")
	game.campaign.relay_hp=0
	expect(game.campaign.result()==-1,"relay destruction overrides timer victory")
	reset(game,3)
	for unit in game.units:
		if unit.team==1: unit.hp=0
	place(game,game.units[0],Vector2i(17,10))
	game.campaign.interact()
	expect(game.campaign.switches[0] and game.campaign.result()==0,"one terminal insufficient")
	expect(game.save_system.save_game(game,path)=="","save partial sabotage")
	game.campaign.switches[0]=false
	expect(game.save_system.load_game(game,path)=="" and game.campaign.switches[0] and not game.campaign.switches[1],"terminal state survives reload")
	place(game,game.units[0],Vector2i(24,6))
	game.campaign.interact()
	expect(game.campaign.switches[1] and game.campaign.result()==1,"two terminals and defeated garrison win")
	if not failures.is_empty():
		finish(game)
		return
	reset(game,0)
	var legacy: Dictionary=game.save_system.snapshot(game)
	legacy.erase("campaign")
	legacy.version=4
	file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	reset(game,3)
	expect(game.save_system.load_game(game,path)=="" and game.campaign.index==0,"v0.2 save migrates to first sector")
	if not failures.is_empty():
		finish(game)
		return
	print("CAMPAIGN OBJECTIVES PASSED; testing actual scene transitions")
	reset(game,0)
	game.won=true
	game.campaign.victory=true
	Engine.set_meta("campaign_transition",1)
	game.campaign.next_mission()

func finish(game: Node):
	print("CAMPAIGN TESTS: "+JSON.stringify(failures))
	game.get_tree().quit(0 if failures.is_empty() else 1)

func gallery(game: Node):
	var capture: RefCounted=load("res://capture_gallery.gd").new()
	for mission in range(4):
		reset(game,mission)
		game.camera_target=game.to_world([Vector2i(13,13),Vector2i(24,7),Vector2i(10,16),Vector2i(21,10)][mission])
		game.zoom=[42,26,32,40][mission]
		if mission==1:
			game.set_door_state(Vector2i(24,9),true)
			place(game,game.units[0],Vector2i(24,8))
			place(game,game.units[1],Vector2i(23,10))
		if mission==3: game.world.roofs_forced_hidden=true
		game.tactics.update_visibility()
		await capture.shot(game,"mission-%d" % (mission+1))
	game.get_tree().quit()


func soak(game: Node):
	Engine.time_scale=30
	var bot: RefCounted=load("res://soak_tests.gd").new()
	var reports: Array=[]
	for mission in range(4):
		reset(game,mission)
		game.rng.seed=2026
		for round_index in range(10):
			await bot.player_turn(game)
			bot.check(game,"sector %d player %d" % [mission,round_index])
			if game.won: break
			await game.end_turn()
			bot.check(game,"sector %d AI %d" % [mission,round_index])
			if game.won: break
		reports.append({"sector":mission+1,"turn":game.turn,"result":game.campaign.result(),"relay_hp":game.campaign.relay_hp})
	var file:=FileAccess.open("res://../build/campaign-soak.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs":reports,"failures":bot.failures},"\t"))
	print("CAMPAIGN SOAK: "+JSON.stringify({"runs":reports,"failures":bot.failures}))
	game.get_tree().quit(0 if bot.failures.is_empty() else 1)
