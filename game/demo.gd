extends RefCounted
## Hands-free demonstration of an actual battle, with normal AP and damage rules.
func run(game: Node):
	game.camera_target=game.to_world(Vector2i(13,13))
	game.zoom=40
	game.update_camera()
	game.note("ДЕМОНСТРАЦИЯ: отряд действует автоматически. Обычная игра — START.cmd.")
	await game.get_tree().create_timer(2).timeout
	var driver: RefCounted=load("res://soak_tests.gd").new()
	for turn_index in range(8):
		if game.won: break
		await driver.player_turn(game)
		if game.won: break
		await game.get_tree().create_timer(1.1).timeout
		await game.end_turn()
		await game.get_tree().create_timer(1.1).timeout
	await game.get_tree().create_timer(3).timeout
	print("DEMO_COMPLETE: turn=%d mission_finished=%s" % [game.turn,game.won])
	game.get_tree().quit()
