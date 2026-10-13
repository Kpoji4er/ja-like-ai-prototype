extends Node3D

var game: Node
var roofs: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var mats := {}

func mat(hex: String, rough: float = 0.9) -> StandardMaterial3D:
	if mats.has(hex): return mats[hex]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	mats[hex] = m
	return m

func box(pos: Vector3, dims: Vector3, color: String, parent: Node = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	parent.add_child(node)
	node.position = pos
	return node

func cylinder(pos: Vector3, radius: float, height: float, color: String, parent: Node = self, top: float = -1) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	parent.add_child(node)
	node.position = pos
	return node

func ball(pos: Vector3, dims: Vector3, color: String, parent: Node = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.height = 2
	mesh.radius = 1
	mesh.radial_segments = 10
	mesh.rings = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	parent.add_child(node)
	node.position = pos
	node.scale = dims
	return node

func rod(a: Vector3, b: Vector3, radius: float, color: String, parent: Node = self) -> MeshInstance3D:
	var node := cylinder((a+b)*0.5,radius,a.distance_to(b),color,parent)
	if abs((b-a).normalized().dot(Vector3.UP)) < 0.99:
		node.look_at_from_position((a+b)*0.5,b,Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT,PI/2)
	return node

func sign_text(text: String, pos: Vector3, size_f: int, color: Color, parent: Node = self) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size_f
	label.pixel_size = 0.007
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	label.position = pos
	return label

func build(owner_game: Node):
	game = owner_game
	rng.seed = 1999
	var ground := box(Vector3(0,-0.22,0),Vector3(76,0.4,64),"736343")
	var gm := ShaderMaterial.new()
	gm.shader = load("res://ground.gdshader")
	ground.material_override = gm
	# A road through a poor Arulcan town, with damaged paint and dusty shoulders.
	for i in range(-13,14):
		box(Vector3(i*2.7,0.004,0),Vector3(1.15,0.012,0.10),"a89968")
	for x in [-21.0,-4.0,14.0]:
		box(Vector3(x,0.025,6.5),Vector3(3.8,0.035,5),"897b58")
	building(Vector2i(5,4),Vector2i(7,6),"c4b18b","ALMACÉN  •  OMERTA",false)
	building(Vector2i(21,3),Vector2i(7,7),"c6bd9c","CLÍNICA",true)
	building(Vector2i(7,18),Vector2i(6,5),"b99c72","BAR  EL  PASO",false)
	# Broken compound wall and sandbag positions define traversable tactical lanes.
	for cell in [Vector2i(17,7),Vector2i(18,7),Vector2i(19,7),Vector2i(27,16),Vector2i(27,17),Vector2i(27,18),Vector2i(18,19),Vector2i(19,19)]:
		low_wall(cell)
	for cell in [Vector2i(14,10),Vector2i(15,10),Vector2i(19,15),Vector2i(20,15),Vector2i(4,18),Vector2i(5,18),Vector2i(23,19)]:
		sandbags(cell)
	car(Vector2i(16,16),"657b70",false)
	car(Vector2i(25,12),"ad9b72",true)
	# Power poles, wires and a faded checkpoint.
	for x in [-25.0,-8.0,10.0,27.0]:
		cylinder(Vector3(x,3.2,-5.8),0.12,6.4,"66553b")
		box(Vector3(x,5.9,-5.8),Vector3(1.8,0.12,0.13),"594734")
		for dx in [-0.65,0.65]: cylinder(Vector3(x+dx,6.1,-5.8),0.09,0.3,"737e76")
	for x in [-25.0,-8.0,10.0]:
		for offset in [-0.65,0.65]:
			for j in range(12):
				var t: float = j/12.0
				var t2: float = (j+1)/12.0
				rod(Vector3(x+offset+t*17,6.25-sin(t*PI)*0.6,-5.8),Vector3(x+offset+t2*17,6.25-sin(t2*PI)*0.6,-5.8),0.018,"282a23")
	box(Vector3(-25,1.5,4.3),Vector3(3.7,1.3,0.13),"415142")
	for x in [-26.4,-23.6]: box(Vector3(x,0.8,4.3),Vector3(0.13,1.8,0.13),"564b39")
	sign_text("OMERTA\nA R U L C O",Vector3(-25,1.5,4.39),55,Color("d6caa6"))
	# Water tank overlooking the town.
	var tank_pos := Vector3(26,0,-18)
	for dx in [-1.1,1.1]:
		for dz in [-1.1,1.1]: rod(tank_pos+Vector3(dx,0,dz),tank_pos+Vector3(dx,5,dz),0.075,"686d5b")
	rod(tank_pos+Vector3(-1.1,0,-1.1),tank_pos+Vector3(1.1,4.8,-1.1),0.045,"686d5b")
	rod(tank_pos+Vector3(-1.1,0,1.1),tank_pos+Vector3(1.1,4.8,1.1),0.045,"686d5b")
	cylinder(tank_pos+Vector3(0,5.4,0),1.8,2.3,"8c8f78")
	cylinder(tank_pos+Vector3(0,6.62,0),1.85,0.18,"737966",self,0.6)
	# Palm silhouettes and scrub vegetation, all deterministic.
	for p in [Vector2(-26,-17),Vector2(-21,15),Vector2(4,-18),Vector2(26,16),Vector2(18,20),Vector2(-27,5),Vector2(5,16),Vector2(29,-7),Vector2(-6,-21)]:
		palm(Vector3(p.x,0,p.y),rng.randf_range(4.5,6.8))
	for i in range(115):
		var p := Vector3(rng.randf_range(-35,35),0,rng.randf_range(-29,29))
		var cell: Vector2i = game.to_cell(p)
		if abs(p.z)<4.8 or game.solid.has(cell) or game.cover.has(cell): continue
		if i%4==0:
			ball(p+Vector3(0,0.18,0),Vector3(0.5,0.3,0.38),["756c50","918165","69654b"][i%3])
		else:
			bush(p,rng.randf_range(0.45,1.0))
	for i in range(600):
		var p := Vector3(rng.randf_range(-35,35),0,rng.randf_range(-29,29))
		if abs(p.z)<4.6 or game.solid.has(game.to_cell(p)): continue
		var h := rng.randf_range(0.15,0.4)
		var tuft := box(p+Vector3(0,h/2,0),Vector3(0.05,h,0.12),["78774a","8b8552","656c42"][i%3])
		tuft.rotation.z = rng.randf_range(-0.45,0.45)
	# Outer terrain undulations remain outside the playable sector.
	for i in range(18):
		var angle := i*TAU/18.0
		ball(Vector3(cos(angle)*45,-2,sin(angle)*38),Vector3(10,rng.randf_range(3,6),8),"6b714c")

func building(cell: Vector2i, cells: Vector2i, wall_color: String, title: String, flat: bool):
	var center: Vector3 = game.to_world(cell) + Vector3((cells.x-1)*game.C/2,0,(cells.y-1)*game.C/2)
	var sx: float = cells.x*game.C
	var sz: float = cells.y*game.C
	for x in range(cell.x,cell.x+cells.x):
		for y in range(cell.y,cell.y+cells.y): game.solid[Vector2i(x,y)] = true
	box(center+Vector3(0,0.13,0),Vector3(sx+0.5,0.26,sz+0.5),"89816a")
	var walls := box(center+Vector3(0,1.65,0),Vector3(sx,3.05,sz),wall_color)
	var plaster := ShaderMaterial.new()
	plaster.shader=load("res://plaster.gdshader")
	plaster.set_shader_parameter("base_color",Color(wall_color))
	walls.material_override=plaster
	box(center+Vector3(0,0.42,0),Vector3(sx+0.04,0.4,sz+0.04),"80775b")
	box(center+Vector3(0,2.96,0),Vector3(sx+0.14,0.2,sz+0.14),"ddd1ad")
	# Front door, frames, dark glass and shutters.
	box(center+Vector3(0,1.13,sz/2+0.025),Vector3(1.25,2.1,0.10),"50482f")
	box(center+Vector3(0,2.26,sz/2+0.06),Vector3(1.48,0.15,0.16),"d7c6a0")
	box(center+Vector3(0,0.24,sz/2+0.45),Vector3(1.9,0.28,0.8),"a59a7c")
	for x in [-sx*0.31,sx*0.31]:
		box(center+Vector3(x,1.85,sz/2+0.04),Vector3(1.75,1.35,0.12),"e0d3ae")
		box(center+Vector3(x,1.85,sz/2+0.12),Vector3(1.46,1.11,0.06),"263d3b")
		for side in [-1,1]:
			box(center+Vector3(x+side*0.95,1.85,sz/2+0.15),Vector3(0.32,1.4,0.1),"597069")
		box(center+Vector3(x,1.85,sz/2+0.17),Vector3(0.06,1.15,0.06),"b7b89a")
		box(center+Vector3(x,1.3,sz/2+0.19),Vector3(1.88,0.13,0.38),"b6a786")
	for side in [-1,1]:
		for z in [-sz*0.28,sz*0.25]:
			box(center+Vector3(side*(sx/2+0.025),1.75,z),Vector3(0.12,1.1,1.55),"ddd0ac")
			box(center+Vector3(side*(sx/2+0.10),1.75,z),Vector3(0.08,0.9,1.3),"344641")
	box(center+Vector3(0,2.75,sz/2+0.14),Vector3(sx*0.70,0.47,0.15),"526455")
	sign_text(title,center+Vector3(0,2.75,sz/2+0.23),42,Color("e2d5af"))
	# Plaster repairs and low weather stains.
	for i in range(14):
		var xx := rng.randf_range(-sx/2+0.3,sx/2-0.3)
		box(center+Vector3(xx,rng.randf_range(0.55,1.0),sz/2+0.011),Vector3(rng.randf_range(0.12,0.5),rng.randf_range(0.07,0.2),0.015),"9e9070")
	var roof := Node3D.new()
	add_child(roof)
	roofs.append(roof)
	if flat:
		box(center+Vector3(0,3.3,0),Vector3(sx+0.4,0.28,sz+0.4),"bbb292",roof)
		for side in [-1,1]: box(center+Vector3(side*sx/2,3.55,0),Vector3(0.22,0.6,sz),wall_color,roof)
		box(center+Vector3(0,3.55,-sz/2),Vector3(sx,0.6,0.22),wall_color,roof)
		cylinder(center+Vector3(2,4.2,-1.7),0.8,1.6,"404d48",roof)
		box(center+Vector3(-2,3.75,0),Vector3(1.5,0.65,1),"82928a",roof)
		# A painted clinic cross.
		box(center+Vector3(sx/2+0.13,2.1,0),Vector3(0.09,1.0,0.27),"ac493a")
		box(center+Vector3(sx/2+0.13,2.1,0),Vector3(0.09,0.27,1),"ac493a")
	else:
		for side in [-1,1]:
			var slab := box(center+Vector3(0,3.65,side*sz/4),Vector3(sx+0.8,0.18,sz/2+0.6),"874d37",roof)
			slab.rotation.x = side*0.23
			for j in range(int((sx+0.7)/0.32)):
				var tile := cylinder(center+Vector3(-sx/2-0.23+j*0.32,3.77,side*sz/4),0.10,sz/2+0.55,["a66547","99573d","b0714d"][j%3],roof)
				tile.rotation.x = PI/2+side*0.23
		rod(center+Vector3(-sx/2-0.4,4.32,0),center+Vector3(sx/2+0.4,4.32,0),0.15,"b47750",roof)
	# Porch awning and supporting wooden posts.
	box(center+Vector3(0,2.4,sz/2+1.15),Vector3(sx*0.65,0.1,1.8),"727d61")
	for x in [-sx*0.30,sx*0.30]: cylinder(center+Vector3(x,1.2,sz/2+1.9),0.065,2.4,"67583f")
	for x in [-sx*0.25,sx*0.25]: box(center+Vector3(x,0.4,sz/2+0.7),Vector3(1.4,0.12,0.38),"69543b")

func low_wall(cell: Vector2i):
	game.cover[cell] = true
	var p: Vector3 = game.to_world(cell)
	box(p+Vector3(0,0.65,0),Vector3(game.C,1.3,0.45),"aaa080")
	box(p+Vector3(0,1.32,0),Vector3(game.C+0.08,0.13,0.53),"c1b697")
	for i in range(3): box(p+Vector3(-0.6+i*0.55,0.32,0.234),Vector3(0.42,0.18,0.03),"86795d")

func sandbags(cell: Vector2i):
	game.cover[cell] = true
	var p: Vector3 = game.to_world(cell)
	for row in range(3):
		for j in range(3):
			ball(p+Vector3((j-1)*0.53+(row%2)*0.13,0.2+row*0.25,0),Vector3(0.34,0.18,0.34),["96906a","a19a76","888460"][(row+j)%3])

func car(cell: Vector2i, color: String, wreck: bool):
	for x in range(cell.x,cell.x+2): game.cover[Vector2i(x,cell.y)] = true
	var p: Vector3 = game.to_world(cell)+Vector3(0.8,0,0)
	box(p+Vector3(0,0.66,0),Vector3(3.9,0.65,1.65),color)
	box(p+Vector3(-0.2,1.25,0),Vector3(1.8,0.72,1.5),color)
	box(p+Vector3(-0.2,1.33,0),Vector3(1.5,0.44,1.54),"293d3b")
	box(p+Vector3(-0.2,1.64,0),Vector3(1.96,0.1,1.58),color)
	for x in [-1.25,1.25]:
		for z in [-0.8,0.8]:
			var tire := cylinder(p+Vector3(x,0.4,z),0.4,0.20,"262b28")
			tire.rotation.x = PI/2
	for x in [-2,2]: box(p+Vector3(x,0.54,0),Vector3(0.13,0.18,1.7),"727771")
	for z in [-0.56,0.56]: box(p+Vector3(1.98,0.8,z),Vector3(0.05,0.23,0.36),"dad2aa")
	if wreck:
		box(p+Vector3(1.1,1.01,0),Vector3(0.8,0.04,1.35),"624a35")
		box(p+Vector3(-0.7,0.84,0.84),Vector3(0.6,0.25,0.02),"80533b")

func bush(p: Vector3, s: float):
	for i in range(3):
		ball(p+Vector3(rng.randf_range(-0.25,0.25),s*0.3,rng.randf_range(-0.25,0.25)),Vector3(s*0.45,s*0.38,s*0.45),["555e36","626c3c","727646"][i])

func palm(p: Vector3, h: float):
	rod(p,p+Vector3(0.35,h,0),0.17,"807051")
	for j in range(14): cylinder(p+Vector3(0.35*j/14,h*j/14,0),0.19,0.10,"655a42")
	for i in range(9):
		var a := TAU*i/9
		var d := Vector3(cos(a),0,sin(a))
		var start := p+Vector3(0.35,h,0)
		var mid := start+d*1.35+Vector3.UP*0.35
		var end := start+d*3.3-Vector3.UP*1.05
		rod(start,mid,0.065,"656b3a")
		rod(mid,end,0.04,"596337")
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var across := Vector3(-d.z,0,d.x)
		for j in range(8):
			var t0 := j/8.0
			var t1 := (j+1)/8.0
			var c0 := start.lerp(end,t0)+Vector3.UP*sin(t0*PI)*0.65
			var c1 := start.lerp(end,t1)+Vector3.UP*sin(t1*PI)*0.65
			var w0 := sin(t0*PI)*0.48
			var w1 := sin(t1*PI)*0.48
			for v in [c0-across*w0,c1-across*w1,c0+across*w0,c0+across*w0,c1-across*w1,c1+across*w1]: surface.add_vertex(v)
		surface.generate_normals()
		var frond := MeshInstance3D.new()
		frond.mesh = surface.commit()
		var leaf_mat := mat("4d6439").duplicate()
		leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		frond.material_override = leaf_mat
		add_child(frond)
		for j in range(6):
			var t := j/6.0
			var point := mid.lerp(end,t)
			var lateral := Vector3(-d.z,-0.2,d.x)*(0.6*(1-t)+0.1)
			rod(point,point+lateral-d*0.25,0.095*(1-t)+0.018,"536c3c")
			rod(point,point-lateral-d*0.25,0.095*(1-t)+0.018,"657943")

func soldier(team: int, index: int) -> Node3D:
	var root := Node3D.new()
	var uniform: String = ["66734c","6d6850","566c60"][index%3] if team==0 else "814937"
	var pants: String = "4a5140" if team==0 else "56583d"
	var skin: String = ["b08b65","d0a37b","795a41"][index%3]
	for side in [-1,1]:
		box(Vector3(side*0.17,0.13,0.06),Vector3(0.22,0.22,0.4),"34372d",root)
		var leg := box(Vector3(side*0.17,0.51,0),Vector3(0.25,0.68,0.25),pants,root)
		leg.name = "LegL" if side==-1 else "LegR"
	box(Vector3(0,1.04,0),Vector3(0.63,0.62,0.35),uniform,root)
	box(Vector3(0,1.06,-0.20),Vector3(0.51,0.48,0.13),"444c37",root)
	box(Vector3(0,1.01,0.24),Vector3(0.47,0.52,0.22),"54583e",root)
	for x in [-0.18,0,0.18]: box(Vector3(x,0.94,-0.29),Vector3(0.14,0.2,0.1),"74704c",root)
	cylinder(Vector3(0,1.43,0),0.105,0.17,skin,root)
	ball(Vector3(0,1.62,0),Vector3(0.19,0.23,0.18),skin,root)
	if index==1 and team==0:
		ball(Vector3(0,1.77,0.015),Vector3(0.195,0.11,0.19),"74563a",root)
	else:
		ball(Vector3(0,1.78,0.015),Vector3(0.235,0.14,0.235),"525c3f" if team==0 else "6a4934",root)
		cylinder(Vector3(0,1.73,-0.01),0.24,0.045,"616849" if team==0 else "6a4934",root)
	rod(Vector3(-0.38,1.24,0),Vector3(-0.32,1.00,-0.30),0.105,uniform,root)
	rod(Vector3(-0.32,1.00,-0.30),Vector3(-0.12,1.12,-0.59),0.08,skin,root)
	rod(Vector3(0.37,1.24,0),Vector3(0.36,1.01,-0.22),0.105,uniform,root)
	rod(Vector3(0.36,1.01,-0.22),Vector3(0.09,1.10,-0.31),0.08,skin,root)
	box(Vector3(0.04,1.13,-0.46),Vector3(0.105,0.13,0.75),"292e2b",root)
	box(Vector3(0.04,1.06,-0.17),Vector3(0.12,0.17,0.22),"6d5037",root)
	rod(Vector3(0.04,1.15,-0.75),Vector3(0.04,1.15,-1.02),0.032,"353936",root)
	box(Vector3(0.04,1.00,-0.43),Vector3(0.085,0.24,0.15),"353b32",root)
	return root
