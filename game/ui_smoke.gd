extends RefCounted
var failures: Array[String]=[]

func expect(value: bool,message: String):
	if not value: failures.append(message)

func key(game: Node,code: Key):
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	game.get_viewport().push_input(event)
	await game.get_tree().process_frame
	event=event.duplicate()
	event.pressed=false
	game.get_viewport().push_input(event)
	await game.get_tree().process_frame

func click(game: Node,control: Control):
	var position: Vector2=game.get_viewport().get_final_transform()*control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=position
	motion.global_position=position
	game.get_viewport().push_input(motion)
	await game.get_tree().process_frame
	var event:=InputEventMouseButton.new()
	event.position=position
	event.global_position=position
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.pressed=true
	game.get_viewport().push_input(event)
	await game.get_tree().process_frame
	event=event.duplicate()
	event.pressed=false
	event.button_mask=0
	game.get_viewport().push_input(event)
	await game.get_tree().process_frame

func run(game: Node):
	game.save_path="res://../build/ui-quicksave.json"
	await game.get_tree().create_timer(0.7).timeout
	await click(game,game.cards[1])
	expect(game.selected==game.units[1],"real mouse event selects Fox card")
	await key(game,KEY_B)
	expect(game.tactics.mode=="burst","burst key dispatch")
	await click(game,game.action_buttons.crouch)
	expect(game.selected.crouched and game.selected.ap==18,"stance button dispatch and AP")
	await key(game,KEY_ESCAPE)
	expect(is_instance_valid(game.menu_panel),"escape opens menu")
	await key(game,KEY_F5)
	expect(FileAccess.file_exists(game.save_path) and not is_instance_valid(game.menu_panel),"F5 works from menu")
	game.selected.ammo=1
	await key(game,KEY_F9)
	expect(game.selected.ammo==30 and game.selected.ap==18,"F9 restores saved state")
	await key(game,KEY_F2)
	expect(game.cinematic and not game.hud.visible,"photo mode hides HUD")
	await key(game,KEY_ESCAPE)
	expect(not game.cinematic and game.hud.visible and is_instance_valid(game.menu_panel),"menu exits photo mode visibly")
	await key(game,KEY_ESCAPE)
	await key(game,KEY_V)
	expect(game.tactical_overlay.enabled,"reachability hotkey")
	await click(game,game.cards[0])
	await key(game,KEY_SPACE)
	var deadline:=Time.get_ticks_msec()+20000
	while game.busy and Time.get_ticks_msec()<deadline: await game.get_tree().process_frame
	expect(game.turn==2 and not game.busy,"space ends exactly one turn after clicking a button")
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/ui-smoke.png"))
	var file:=FileAccess.open("res://../build/ui-smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures},"\t"))
	file.close()
	print("UI_SMOKE: "+JSON.stringify(failures))
	game.get_tree().quit(0 if failures.is_empty() else 1)
