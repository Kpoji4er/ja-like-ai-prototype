extends RefCounted
const BASELINE:="res://../build/test-baseline.json"
const ROUNDTRIP:="res://../build/test-roundtrip.json"

func expect(value: bool, message: String, failures: Array[String]):
	if not value: failures.append(message)

func restore(g: Node, failures: Array[String]):
	g.busy=false
	g.enemy_turn=false
	g.won=false
	var error: String=g.save_system.load_game(g,BASELINE)
	expect(error=="","baseline restore: "+error,failures)

func run(g: Node, failures: Array[String]):
	Engine.time_scale=12
	expect(g.save_system.save_game(g,BASELINE)=="","baseline save",failures)
	for i in range(3):
		g.cards[i].pressed.emit()
		expect(g.selected==g.units[i],"squad card callback %d" % i,failures)
	restore(g,failures)
	var u: Dictionary=g.units[0]
	var enemy: Dictionary=g.units[3]
	g.tactical_overlay.enabled=true
	u.ap=0
	g.refresh_ui()
	expect(g.tactical_overlay.mesh==null,"zero AP overlay has no invalid empty surface",failures)
	u.ap=20
	g.refresh_ui()
	expect(g.tactical_overlay.mesh!=null,"reachable overlay is generated",failures)
	g.tactical_overlay.enabled=false
	# Walls meeting at a corner must not leave a diagonal firing slit.
	g.solid[Vector2i(1,0)]=true
	g.solid[Vector2i(0,1)]=true
	expect(not g.line_of_sight(Vector2i(0,0),Vector2i(2,2)),"solid diagonal corner blocks LOS",failures)
	g.solid.erase(Vector2i(1,0))
	g.solid.erase(Vector2i(0,1))
	# Door interaction, window cover and automatic interior cutaway.
	var door_cell:=Vector2i(8,9)
	var door: Dictionary=g.doors[door_cell]
	expect(not g.walkable(door_cell,u),"closed door blocks movement",failures)
	g.interact_door(door_cell)
	expect(not door.open and u.ap==20,"distant door cannot be opened",failures)
	u.cell=door_cell+Vector2i.DOWN
	u.node.position=g.to_world(u.cell)
	g.interact_door(door_cell)
	expect(door.open and u.ap==18 and g.walkable(door_cell,u),"open door charges two AP and clears route",failures)
	var route: Array[Vector2i]=g.find_path(u.cell,door_cell+Vector2i.UP,u)
	expect(route.size()==3,"door leads to interior",failures)
	await g.move_unit(u,route)
	expect(not g.world.rooms[0].roof.visible and not g.world.rooms[0].upper.visible,"interior automatically cuts away walls and roof",failures)
	u.cell=door_cell
	u.node.position=g.to_world(u.cell)
	var door_ap: int=u.ap
	g.interact_door(door_cell)
	expect(door.open and u.ap==door_ap,"occupied door cannot close",failures)
	expect(g.save_system.save_game(g,ROUNDTRIP)=="","save actor in open doorway",failures)
	g.set_door_state(door_cell,false)
	expect(g.save_system.load_game(g,ROUNDTRIP)=="" and door.open and u.cell==door_cell,"restore open doorway before actor occupancy",failures)
	var malformed: Dictionary=g.save_system.snapshot(g)
	malformed.doors[0][2]="open"
	expect(g.save_system.validate(malformed,g)!="","reject malformed door state",failures)
	expect(g.windows.has(Vector2i(5,6)) and not g.walkable(Vector2i(5,6),u),"window is cover rather than a passage",failures)
	restore(g,failures)
	expect(not door.open and g.world.rooms[0].roof.visible,"baseline restores closed doors and roofs",failures)
	# A remembered contact inside a building makes the AI approach and open its door.
	u.cell=Vector2i(8,7)
	u.node.position=g.to_world(u.cell)
	for i in [1,2]: g.units[i].hp=0
	enemy.cell=Vector2i(8,11)
	enemy.node.position=g.to_world(enemy.cell)
	enemy.alert=u.cell
	g.tactics.update_visibility()
	g.busy=true
	g.enemy_turn=true
	await g.tactics.ai_turn(enemy)
	expect(door.open and enemy.ap<=16,"AI opens a door while pursuing remembered contact",failures)
	restore(g,failures)
	# Explosive props remove their real obstacle and participate in saves.
	var barrel_cell:=Vector2i(18,13)
	u.cell=Vector2i(15,13)
	u.node.position=g.to_world(u.cell)
	enemy.cell=Vector2i(18,12)
	enemy.node.position=g.to_world(enemy.cell)
	g.tactics.update_visibility()
	await g.explosives.shoot(barrel_cell)
	expect(u.ap==14 and u.ammo==29 and not g.busy,"barrel shot accounting",failures)
	expect(enemy.hp==29 and u.hp==67,"barrel blast falloff and friendly fire",failures)
	expect(not g.cover.has(barrel_cell) and not g.explosives.target_at(barrel_cell),"destroyed barrel opens route",failures)
	u.cell=barrel_cell
	u.node.position=g.to_world(u.cell)
	expect(g.save_system.save_game(g,ROUNDTRIP)=="","save actor on destroyed prop",failures)
	g.explosives.set_intact(barrel_cell,true)
	expect(g.save_system.load_game(g,ROUNDTRIP)=="" and not g.explosives.target_at(barrel_cell),"restore destroyed barrel before validating actor",failures)
	restore(g,failures)
	# Equipment: invalid actions must not spend either AP or an item.
	u.ammo=0
	u.ap=4
	g.tactics.reload_weapon()
	expect(u.ammo==0 and u.ap==4,"reload insufficient AP is atomic",failures)
	u.ap=20
	u.reserve=1
	g.tactics.reload_weapon()
	expect(u.ammo==1 and u.reserve==0 and u.ap==15,"partial magazine conserves ammunition",failures)
	u.ammo=0
	u.ap=20
	await g.shoot(u,enemy)
	expect(u.ap==20 and not g.busy,"empty magazine cannot shoot",failures)
	g.tactics.toggle_watch()
	expect(not u.watch and u.ap==20,"empty magazine cannot watch",failures)
	u.ammo=30
	g.tactics.toggle_watch()
	expect(u.watch and u.ap==14,"watch reserves AP",failures)
	g.tactics.toggle_watch()
	expect(not u.watch and u.ap==20,"watch cancellation refunds once",failures)
	g.tactics.cancel_watch(u)
	expect(u.ap==20,"no duplicate watch refund",failures)
	u.ap=10
	u.ammo=1
	u.reserve=60
	g.tactics.toggle_watch()
	g.tactics.reload_weapon()
	expect(not u.watch and u.ap==5 and u.ammo==30 and u.reserve==31,"reload can spend refunded overwatch AP",failures)
	restore(g,failures)
	# Medic role, range and finite consumables.
	var medic: Dictionary=g.units[1]
	medic.cell=Vector2i(7,16)
	g.selected=medic
	u.hp=40
	g.tactics.heal(u)
	expect(u.hp==90 and medic.ap==14 and medic.medkits==1,"Fox medic bonus / item and AP",failures)
	u.hp=100
	g.tactics.heal(u)
	expect(medic.ap==14 and medic.medkits==1,"full health does not waste medical kit",failures)
	u.hp=40
	u.cell=Vector2i(18,16)
	g.tactics.heal(u)
	expect(u.hp==40 and medic.ap==14,"healing requires adjacency",failures)
	restore(g,failures)
	# Hidden enemies cannot be selected, shot, or seen through solid structures.
	for i in range(3): g.units[i].cell=Vector2i(4,3+i)
	enemy.cell=Vector2i(13,5)
	g.tactics.update_visibility()
	expect(not enemy.visible and not enemy.node.visible,"building hides enemy from entire squad",failures)
	var before_ammo: int=u.ammo
	await g.shoot(u,enemy)
	expect(u.ammo==before_ammo and u.ap==20,"hidden target cannot be fired upon",failures)
	restore(g,failures)
	# Prepaid reaction is fired exactly once, during a hostile movement phase.
	u.cell=Vector2i(14,12)
	u.node.position=g.to_world(u.cell)
	enemy.cell=Vector2i(16,12)
	enemy.node.position=g.to_world(enemy.cell)
	g.tactics.update_visibility()
	g.tactics.toggle_watch()
	g.busy=true
	g.enemy_turn=true
	await g.tactics.trigger_reactions(enemy)
	expect(not u.watch and u.ap==14 and u.ammo==29,"reaction fires once without charging twice",failures)
	await g.tactics.trigger_reactions(enemy)
	expect(u.ammo==29,"reaction cannot repeat",failures)
	restore(g,failures)
	# Blast respects friendly fire and consumes one grenade only.
	u.cell=Vector2i(14,12)
	u.node.position=g.to_world(u.cell)
	enemy.cell=Vector2i(17,10)
	enemy.node.position=g.to_world(enemy.cell)
	medic.cell=Vector2i(17,11)
	medic.node.position=g.to_world(medic.cell)
	g.tactics.update_visibility()
	await g.tactics.throw_grenade(Vector2i(17,10))
	expect(u.ap==12 and u.grenades==0 and not g.busy,"grenade AP, charge, completion",failures)
	expect(enemy.hp==35 and medic.hp==52,"blast falloff and friendly fire",failures)
	restore(g,failures)
	# A full game state round trip preserves resource counts and RNG continuation.
	u.ammo=7
	u.crouched=true
	u.ap=13
	g.turn=4
	var state: int=g.rng.state
	var expected_roll: int=g.rng.randi()
	g.rng.state=state
	expect(g.save_system.save_game(g,ROUNDTRIP)=="","roundtrip save",failures)
	u.ammo=1
	u.ap=0
	g.turn=9
	expect(g.save_system.load_game(g,ROUNDTRIP)=="","roundtrip load",failures)
	expect(u.ammo==7 and u.ap==13 and u.crouched and g.turn==4,"restore equipment, pose and turn",failures)
	expect(g.rng.randi()==expected_roll,"RNG continuation survives save",failures)
	var invalid: Dictionary=g.save_system.snapshot(g)
	invalid.units[0].hp=-99
	expect(g.save_system.validate(invalid,g)!="","reject negative health",failures)
	invalid=g.save_system.snapshot(g)
	invalid.units[1].cell=invalid.units[0].cell
	expect(g.save_system.validate(invalid,g)!="","reject overlapping live actors",failures)
	invalid=g.save_system.snapshot(g)
	invalid.units[0].ammo="not a number"
	expect(g.save_system.validate(invalid,g)!="","reject malformed number",failures)
	var broken:=FileAccess.open("res://../build/test-corrupt.json",FileAccess.WRITE)
	broken.store_string("{broken json")
	broken.close()
	var hp_before: int=u.hp
	expect(g.save_system.load_game(g,"res://../build/test-corrupt.json")!="" and u.hp==hp_before,"corrupt save must not mutate game",failures)
	expect(g.save_system.save_game(g,ROUNDTRIP)=="","atomic overwrite of existing save",failures)
	restore(g,failures)
	# Defeat can be recovered through a saved battle, even while death tweens exist.
	for i in range(3): g.apply_damage(g.units[i],100,enemy)
	g.check_outcome()
	expect(g.won and is_instance_valid(g.outcome_panel),"defeat creates an outcome panel",failures)
	restore(g,failures)
	await g.get_tree().create_timer(0.4).timeout
	expect(not g.won and not is_instance_valid(g.outcome_panel) and u.node.rotation.z==0 and u.hp==100,"load after defeat cancels death animation and outcome",failures)
	if failures.is_empty(): print("TACTICAL TESTS PASSED: equipment, medic, visibility, reaction, grenade, saves, corruption handling, squad controls")
