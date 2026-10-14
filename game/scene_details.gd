extends Node3D
var w: Node
var game: Node

func build(world: Node, owner_game: Node):
	w=world
	game=owner_game
	for cell in [Vector2i(10,14),Vector2i(12,14),Vector2i(11,11),Vector2i(15,18),Vector2i(20,17)]:
		game.cover[cell]=true
		crates(game.to_world(cell))
	for p in [Vector3(-19,0,-4.8),Vector3(20,0,-4.6),Vector3(-12,0,11.4)]:
		barrel(p,"83533d")
		barrel(p+Vector3(0.75,0,0.25),"59694c")
		w.box(p+Vector3(1.4,0.2,0.05),Vector3(0.65,0.4,0.55),"80704b")
	# A public notice, faded shop poster and small hand-painted graffiti.
	var storefront: Node3D=w.rooms[0].upper
	w.box(Vector3(-15.7,1.65,-5.33),Vector3(0.7,1.0,0.025),"aa9c71",storefront)
	w.sign_text("SE BUSCA\n────\nRECOMPENSA",Vector3(-15.7,1.65,-5.30),19,Color("493c2e"),storefront)
	w.sign_text("LIBERTAD",Vector3(-9.5,0.77,-5.31),26,Color("784e36"),storefront)
	# Clinic first-aid station with a stretcher and supply boxes under its awning.
	w.box(Vector3(18.5,0.75,-4.3),Vector3(1.5,0.12,0.65),"9b9c77")
	for x in [18.0,19.0]: w.rod(Vector3(x,0,-4.3),Vector3(x,0.7,-4.3),0.035,"777e6e")
	w.box(Vector3(12,0.5,-4.3),Vector3(0.8,1,0.5),"66745b")
	w.box(Vector3(12,0.57,-4.035),Vector3(0.10,0.34,0.025),"d8d0af")
	w.box(Vector3(12,0.57,-4.035),Vector3(0.34,0.10,0.025),"d8d0af")
	# Telegraph cabinet, rubble and a checkpoint gate.
	w.box(Vector3(7.3,0.72,5.7),Vector3(0.65,1.44,0.55),"657469")
	w.box(Vector3(7.3,0.8,6.0),Vector3(0.49,0.9,0.035),"829080")
	for i in range(3): w.box(Vector3(7.3,1.08-i*0.1,6.025),Vector3(0.3,0.025,0.025),"424d42")
	for x in [22.6,28.8]: w.cylinder(Vector3(x,1,4.8),0.085,2,"685e43")
	var arm: MeshInstance3D=w.box(Vector3(25.7,1.6,4.8),Vector3(6.1,0.14,0.14),"aa9c6b")
	arm.rotation.z=0.07
	for i in range(11):
		var stripe: MeshInstance3D=w.box(Vector3(22.8+i*0.52,1.6+(i-5)*0.035,4.89),Vector3(0.25,0.15,0.03),"6d4434")
		stripe.rotation.z=0.07
	# These accents are flat decals/very small debris, not movement blockers.
	for i in range(40):
		var p:=Vector3(w.rng.randf_range(-25,27),0.02,w.rng.randf_range(-4,4))
		var scrap: MeshInstance3D=w.box(p,Vector3(w.rng.randf_range(0.08,0.23),0.012,w.rng.randf_range(0.1,0.3)),["a5966f","74755f","b3ac8e"][i%3])
		scrap.rotation.y=w.rng.randf()*TAU
	for i in range(14):
		var p:=Vector3(-5+i*0.4,0.025,3.0+sin(i)*0.08)
		w.box(p,Vector3(0.27,0.01,0.10),"4b4e3c")
	# Flag carries the scene's small continuous animation.
	w.cylinder(Vector3(22.3,2.7,-5.1),0.045,5.4,"777c66")
	var flag:=MeshInstance3D.new()
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(1.8,0.95)
	mesh.subdivide_width=12
	mesh.subdivide_depth=6
	flag.mesh=mesh
	flag.position=Vector3(23.2,4.8,-5.1)
	flag.rotation_degrees=Vector3(90,0,0)
	var material:=ShaderMaterial.new()
	material.shader=load("res://flag.gdshader")
	flag.material_override=material
	w.add_child(flag)

func crates(p: Vector3):
	for i in range(2):
		var at:=p+Vector3((i-0.5)*0.65,0.43,0)
		w.box(at,Vector3(0.65,0.86,0.68),"796b45")
		for y in [-0.28,0.28]: w.box(at+Vector3(0,y,0.35),Vector3(0.66,0.08,0.04),"a18b5a")
		for x in [-0.22,0.22]: w.box(at+Vector3(x,0,0.35),Vector3(0.06,0.86,0.04),"4f583b")
	w.box(p+Vector3(0.18,1.06,0),Vector3(0.65,0.4,0.58),"67704b")
	w.sign_text("7.62",p+Vector3(0.18,1.08,0.30),18,Color("d2bd86"))

func barrel(p: Vector3,color: String):
	w.cylinder(p+Vector3(0,0.54,0),0.34,1.08,color)
	for y in [0.07,0.31,0.78,1.06]: w.cylinder(p+Vector3(0,y,0),0.355,0.045,"4a4d3a")
	w.cylinder(p+Vector3(0,1.09,0),0.32,0.02,"63563d")
	w.cylinder(p+Vector3(0.14,1.12,0.06),0.055,0.025,"303a2f")
