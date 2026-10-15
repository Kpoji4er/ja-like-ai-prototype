extends Node3D

var game: Node
var roofs: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var mats := {}
var textures: Dictionary={}
var rooms: Array[Dictionary]=[]
var roofs_forced_hidden:=false

func texture_file(filename: String) -> ImageTexture:
	if textures.has(filename): return textures[filename]
	var image:=Image.load_from_file("res://assets/textures/"+filename)
	image.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(image)
	textures[filename]=texture
	return texture

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
	gm.set_shader_parameter("ground_color",texture_file("ground-color.jpg"))
	gm.set_shader_parameter("ground_normal",texture_file("ground-normal.jpg"))
	ground.material_override = gm
	if game.sector_index>0:
		gm.set_shader_parameter("road_axis",1.0 if game.sector_index==1 else 0.0)
		gm.set_shader_parameter("road_strength",0.0 if game.sector_index==2 else 1.0)
		load("res://sectors.gd").new().build(self,game,game.sector_index)
		return
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
		low_wall(cell,PI/2 if cell.x==27 else 0.0)
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
		if abs(p.z)<4.8 or game.solid.has(cell) or game.cover.has(cell) or interior_cell(cell): continue
		if i%4==0:
			ball(p+Vector3(0,0.18,0),Vector3(0.5,0.3,0.38),["756c50","918165","69654b"][i%3])
		else:
			bush(p,rng.randf_range(0.45,1.0))
	for i in range(600):
		var p := Vector3(rng.randf_range(-35,35),0,rng.randf_range(-29,29))
		if abs(p.z)<4.6 or game.solid.has(game.to_cell(p)) or interior_cell(game.to_cell(p)): continue
		var h := rng.randf_range(0.15,0.4)
		var tuft := box(p+Vector3(0,h/2,0),Vector3(0.05,h,0.12),["78774a","8b8552","656c42"][i%3])
		tuft.rotation.z = rng.randf_range(-0.45,0.45)
	# Outer terrain undulations remain outside the playable sector.
	for i in range(18):
		var angle := i*TAU/18.0
		ball(Vector3(cos(angle)*45,-2,sin(angle)*38),Vector3(10,rng.randf_range(3,6),8),"6b714c")

func building(cell: Vector2i, cells: Vector2i, wall_color: String, title: String, flat: bool):
	load("res://buildings.gd").new().build(self,game,cell,cells,wall_color,title,flat)

func low_wall(cell: Vector2i, angle: float=0.0, corner: bool=false):
	game.cover[cell] = true
	var p: Vector3 = game.to_world(cell)
	var pieces: Array[MeshInstance3D]=[]
	pieces.append(box(p+Vector3(0,0.65,0),Vector3(game.C,1.3,0.45),"aaa080"))
	pieces.append(box(p+Vector3(0,1.32,0),Vector3(game.C+0.08,0.13,0.53),"c1b697"))
	for i in range(3): pieces.append(box(p+Vector3(-0.6+i*0.55,0.32,0.234),Vector3(0.42,0.18,0.03),"86795d"))
	# Join the perpendicular run at the corner without extending into a free cell.
	if corner:
		pieces.append(box(p+Vector3(0,0.65,-game.C/4),Vector3(0.45,1.3,game.C/2),"aaa080"))
		pieces.append(box(p+Vector3(0,1.32,-game.C/4),Vector3(0.53,0.13,game.C/2+0.04),"c1b697"))
	for piece in pieces:
		piece.position=p+(piece.position-p).rotated(Vector3.UP,angle)
		piece.rotation.y=angle

func sandbags(cell: Vector2i):
	game.cover[cell] = true
	var p: Vector3 = game.to_world(cell)
	for row in range(3):
		for j in range(3):
			ball(p+Vector3((j-1)*0.53+(row%2)*0.13,0.2+row*0.25,0),Vector3(0.34,0.18,0.34),["96906a","a19a76","888460"][(row+j)%3])

func car(cell: Vector2i, color: String, wreck: bool):
	load("res://vehicles.gd").new().car(self,game,cell,color,wreck)

func bush(p: Vector3, s: float):
	for i in range(3):
		ball(p+Vector3(rng.randf_range(-0.25,0.25),s*0.3,rng.randf_range(-0.25,0.25)),Vector3(s*0.45,s*0.38,s*0.45),["555e36","626c3c","727646"][i])

func palm(p: Vector3, h: float):
	load("res://vegetation.gd").new().palm(self,p,h)

func soldier(team: int, index: int) -> Node3D:
	return load("res://characters.gd").new().build(self,team,index)

func batch_static():
	# Static props sharing a material become a single mesh. Characters and effects
	# stay separate; shader-driven foliage retains its local animation space.
	batch_group(self)
	for roof in roofs: batch_group(roof)
	for room in rooms: batch_group(room.upper)

func interior_cell(cell: Vector2i) -> bool:
	for room in rooms:
		if room.bounds.has_point(cell): return true
	return false

func update_cutaways():
	for room in rooms:
		var cut: bool=roofs_forced_hidden
		for unit in game.units:
			if unit.hp>0 and unit.visible and room.bounds.has_point(unit.cell): cut=true
		room.roof.visible=not cut
		room.upper.visible=not cut
	for cell in game.doors:
		var door: Dictionary=game.doors[cell]
		var near:=false
		for unit in game.units:
			if unit.team==0 and unit.hp>0 and Vector2(unit.cell).distance_to(Vector2(cell))<4.5: near=true
		door.marker.visible=near and not game.cinematic and not door.open
		door.marker.text="ОТКРЫТО" if door.open else "ДВЕРЬ · 2 ОД"

func batch_group(parent: Node3D):
	var batches: Dictionary={}
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		var material: Material=child.get_active_material(0)
		if material==null: continue
		if material is ShaderMaterial and material.shader.resource_path!="res://plaster.gdshader": continue
		var key:=material.get_instance_id()
		if not batches.has(key): batches[key]={"material":material,"nodes":[]}
		batches[key].nodes.append(child)
	for key in batches:
		var data: Dictionary=batches[key]
		if data.nodes.size()<2: continue
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in data.nodes: surface.append_from(node.mesh,0,node.transform)
		var mesh:=MeshInstance3D.new()
		mesh.name="StaticBatch"
		mesh.mesh=surface.commit()
		mesh.material_override=data.material
		parent.add_child(mesh)
		for node in data.nodes: node.free()
