extends RefCounted
## Reproducible real-renderer views for release QA; never writes outside project.
func shot(game: Node, filename: String):
	game.refresh_ui()
	game.update_camera()
	await game.get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var path:=ProjectSettings.globalize_path("res://../build/"+filename+".png")
	game.get_viewport().get_texture().get_image().save_png(path)
	print("GALLERY_SAVED: "+filename)

func run(game: Node):
	await shot(game,"preview")
	game.toggle_menu()
	await shot(game,"briefing")
	game.toggle_menu()
	game.camera_target=game.to_world(Vector2i(8,8))
	game.zoom=24
	game.set_door_state(Vector2i(8,9),true)
	game.units[0].cell=Vector2i(8,8)
	game.units[1].cell=Vector2i(7,8)
	game.units[2].cell=Vector2i(8,10)
	for u in game.units: u.node.position=game.to_world(u.cell)
	game.tactics.update_visibility()
	game.note("Демонстрация интерьера: открытая дверь, окна-укрытия, автоматический срез крыши.")
	await shot(game,"interior")
	game.tactical_overlay.enabled=true
	game.tactical_overlay.rebuild()
	await shot(game,"movement-overlay")
	game.tactical_overlay.enabled=false
	game.camera_target=game.to_world(Vector2i(10,13))
	game.zoom=30
	game.yaw=-0.4
	game.cinematic=true
	game.hud.visible=false
	game.world.roofs_forced_hidden=false
	game.units[0].cell=Vector2i(10,15)
	game.units[1].cell=Vector2i(9,15)
	game.units[2].cell=Vector2i(10,16)
	for u in game.units: u.node.position=game.to_world(u.cell)
	game.tactics.update_visibility()
	await shot(game,"squad")
	game.get_tree().quit()
