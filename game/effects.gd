extends Node3D
var game: Node
var cosmetic_rng:=RandomNumberGenerator.new()

func initialize(owner_game: Node):
	game=owner_game
	cosmetic_rng.seed=3501

func float_text(pos: Vector3, text: String, color: Color):
	if game.test_mode: return
	var label:=Label3D.new()
	label.text=text
	label.font_size=52
	label.pixel_size=0.012
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate=color
	label.outline_modulate=Color("162019")
	label.outline_size=10
	label.no_depth_test=true
	add_child(label)
	label.position=pos
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(label,"position:y",pos.y+1.3,1.2)
	tween.tween_property(label,"modulate:a",0.0,0.5).set_delay(0.7)
	tween.chain().tween_callback(label.queue_free)

func burst_dust(pos: Vector3, count: int, tint: Color, force: float=1.0):
	if game.test_mode: return
	for i in range(count):
		var particle: MeshInstance3D=game.world.ball(pos,Vector3.ONE*cosmetic_rng.randf_range(0.07,0.18),"ae9b74",self)
		var material:=StandardMaterial3D.new()
		material.albedo_color=tint
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		particle.material_override=material
		var delta_v:=Vector3(cosmetic_rng.randf_range(-1,1),cosmetic_rng.randf_range(0.2,1.7),cosmetic_rng.randf_range(-1,1))*force
		var tween:=create_tween().set_parallel(true)
		tween.tween_property(particle,"position",pos+delta_v,0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle,"scale",Vector3.ONE*0.02,0.7)
		tween.tween_property(material,"albedo_color:a",0.0,0.7)
		tween.chain().tween_callback(particle.queue_free)

func grenade_arc(start: Vector3, finish: Vector3):
	var grenade: MeshInstance3D=game.world.ball(start,Vector3.ONE*0.13,"414c35",self)
	var tween:=create_tween()
	tween.tween_method(func(t: float): grenade.position=start.lerp(finish,t)+Vector3.UP*sin(t*PI)*4,0.0,1.0,0.65)
	await tween.finished
	grenade.queue_free()

func explosion(pos: Vector3):
	burst_dust(pos,26,Color("b09b73"),3.2)
	var flash:=OmniLight3D.new()
	flash.position=pos+Vector3.UP
	flash.light_color=Color("ffad59")
	flash.light_energy=7
	flash.omni_range=8
	add_child(flash)
	var tween:=create_tween()
	tween.tween_property(flash,"light_energy",0.0,0.3)
	tween.tween_callback(flash.queue_free)
	game.camera_shake=0.3
	if is_instance_valid(game.explosion_sound): game.explosion_sound.play()
