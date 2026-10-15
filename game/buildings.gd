extends RefCounted
var w: Node
var g: Node

func build(world: Node, game: Node, cell: Vector2i, cells: Vector2i, wall_color: String, title: String, flat: bool):
	w=world
	g=game
	var center: Vector3=g.to_world(cell)+Vector3((cells.x-1)*g.C/2,0,(cells.y-1)*g.C/2)
	var sx: float=cells.x*g.C
	var sz: float=cells.y*g.C
	var upper:=Node3D.new()
	upper.name="CutawayWalls"
	w.add_child(upper)
	var roof:=Node3D.new()
	roof.name="Roof"
	w.add_child(roof)
	w.roofs.append(roof)
	w.rooms.append({"bounds":Rect2i(cell,cells),"upper":upper,"roof":roof})
	var plaster:=ShaderMaterial.new()
	plaster.shader=load("res://plaster.gdshader")
	plaster.set_shader_parameter("base_color",Color(wall_color))
	plaster.set_shader_parameter("plaster_color",w.texture_file("plaster-color.jpg"))
	plaster.set_shader_parameter("plaster_normal",w.texture_file("plaster-normal.jpg"))
	w.box(center+Vector3(0,-0.08,0),Vector3(sx+0.3,0.2,sz+0.3),"8b8062")
	var door_cell:=Vector2i(cell.x+cells.x/2,cell.y+cells.y-1)
	for x in range(cell.x,cell.x+cells.x):
		for y in range(cell.y,cell.y+cells.y):
			var at:=Vector2i(x,y)
			var edge: bool=x==cell.x or x==cell.x+cells.x-1 or y==cell.y or y==cell.y+cells.y-1
			if not edge:
				var floor_pos: Vector3=g.to_world(at)
				var color: String=(["a8ac95","c4c2a8"][(x+y)%2] if flat else ["826d4b","887650"][(x+y)%2])
				w.box(floor_pos+Vector3.UP*0.035,Vector3(g.C-0.02,0.035,g.C-0.02),color)
				continue
			g.solid[at]=true
			var front_back: bool=y==cell.y or y==cell.y+cells.y-1
			var wall_pos: Vector3=g.to_world(at)
			if front_back: wall_pos.z=center.z+(-sz/2 if y==cell.y else sz/2)
			else: wall_pos.x=center.x+(-sx/2 if x==cell.x else sx/2)
			var width:=Vector3(g.C,0,0.24) if front_back else Vector3(0.24,0,g.C)
			if at==door_cell:
				segment(wall_pos,width,2.54,0.98,plaster,upper)
				make_door(at,wall_pos,upper)
				continue
			var window: bool=((front_back and x in [cell.x+1,cell.x+cells.x-2]) or (not front_back and y in [cell.y+2,cell.y+cells.y-3]))
			segment(wall_pos,width,0.28,0.56,plaster,w)
			if window:
				g.windows[at]=true
				g.cover[at]=true
				segment(wall_pos,width,0.76,0.4,plaster,w)
				segment(wall_pos,width,2.60,0.86,plaster,upper)
				window_frame(wall_pos,front_back,w)
			else: segment(wall_pos,width,1.80,2.48,plaster,upper)
	# Frieze and a readable sign are part of the automatic cutaway.
	w.box(center+Vector3(0,2.98,0),Vector3(sx+0.14,0.18,sz+0.14),"d4c7a5",upper)
	w.box(center+Vector3(0,2.68,sz/2+0.14),Vector3(sx*0.70,0.42,0.15),"526455",upper)
	w.sign_text(title,center+Vector3(0,2.68,sz/2+0.23),42,Color("e2d5af"),upper)
	if flat:
		w.box(center+Vector3(0,3.3,0),Vector3(sx+0.4,0.28,sz+0.4),"bbb292",roof)
		for side in [-1,1]: w.box(center+Vector3(side*sx/2,3.55,0),Vector3(0.22,0.6,sz),wall_color,roof)
		w.box(center+Vector3(0,3.55,-sz/2),Vector3(sx,0.6,0.22),wall_color,roof)
		w.cylinder(center+Vector3(2,4.2,-1.7),0.8,1.6,"404d48",roof)
		w.box(center+Vector3(-2,3.75,0),Vector3(1.5,0.65,1),"82928a",roof)
		w.box(center+Vector3(sx/2+0.14,2.1,0),Vector3(0.09,1.0,0.27),"ac493a",upper)
		w.box(center+Vector3(sx/2+0.14,2.1,0),Vector3(0.09,0.27,1),"ac493a",upper)
	else:
		for side in [-1,1]:
			var slab: MeshInstance3D=w.box(center+Vector3(0,3.65,side*sz/4),Vector3(sx+0.8,0.18,sz/2+0.6),"874d37",roof)
			slab.rotation.x=side*0.23
			for j in range(int((sx+0.7)/0.32)):
				var tile: MeshInstance3D=w.cylinder(center+Vector3(-sx/2-0.23+j*0.32,3.77,side*sz/4),0.10,sz/2+0.55,["a66547","99573d","b0714d"][j%3],roof)
				tile.rotation.x=PI/2+side*0.23
		w.rod(center+Vector3(-sx/2-0.4,4.32,0),center+Vector3(sx/2+0.4,4.32,0),0.15,"b47750",roof)
	w.box(center+Vector3(0,2.4,sz/2+1.15),Vector3(sx*0.65,0.1,1.8),"727d61",upper)
	for x in [-sx*0.30,sx*0.30]: w.cylinder(center+Vector3(x,1.2,sz/2+1.9),0.065,2.4,"67583f",upper)
	# Furniture occupies real tactical cells; the floor and door lane remain clear.
	var table_cell:=cell+Vector2i(2,2)
	g.cover[table_cell]=true
	var table_pos: Vector3=g.to_world(table_cell)
	w.box(table_pos+Vector3.UP*0.85,Vector3(1.3,0.13,1.05),"9e9d7b" if flat else "695238")
	for dx in [-0.53,0.53]:
		for dz in [-0.4,0.4]: w.box(table_pos+Vector3(dx,0.42,dz),Vector3(0.09,0.84,0.09),"4e503c")
	w.box(table_pos+Vector3(0.15,0.96,0),Vector3(0.38,0.10,0.25),"c9c1a1")
	var cabinet_cell:=cell+Vector2i(cells.x-2,1)
	g.cover[cabinet_cell]=true
	w.box(g.to_world(cabinet_cell)+Vector3.UP*0.65,Vector3(1.1,1.3,0.5),"6b785e" if flat else "725f3d")

func segment(pos: Vector3, width: Vector3, y: float, height: float, material: Material, parent: Node):
	var mesh: MeshInstance3D=w.box(pos+Vector3.UP*y,Vector3(width.x,height,width.z),"b9ad8b",parent)
	mesh.material_override=material

func window_frame(pos: Vector3, front: bool, parent: Node):
	var frame:=Node3D.new()
	parent.add_child(frame)
	frame.position=pos
	# Window frames stay visible in cutaway mode to identify firing apertures.
	w.box(Vector3(0,0.93,0),Vector3(1.78,0.12,0.46),"dfd1aa",frame)
	if not front: frame.rotation.y=PI/2
	for x in [-0.77,0.77]: w.box(Vector3(x,1.57,0),Vector3(0.13,1.28,0.3),"597069",frame)
	for y in [0.98,2.15]: w.box(Vector3(0,y,0),Vector3(1.65,0.13,0.3),"597069",frame)
	w.box(Vector3(0,1.57,0),Vector3(0.055,1.13,0.09),"6e7c66",frame)
	w.box(Vector3(0,1.56,0),Vector3(1.45,0.045,0.09),"6e7c66",frame)
	for side in [-1,1]: w.box(Vector3(side*0.94,1.57,0.05),Vector3(0.22,1.3,0.1),"597069",frame)

func make_door(cell: Vector2i,pos: Vector3,parent: Node):
	var pivot:=Node3D.new()
	pivot.name="Door"
	parent.add_child(pivot)
	pivot.position=pos+Vector3(-0.71,0,0)
	w.box(Vector3(0.71,1.05,0),Vector3(1.42,2.1,0.12),"5f5036",pivot)
	for y in [0.55,1.55]: w.box(Vector3(0.71,y,0.075),Vector3(1.10,0.7,0.025),"756240",pivot)
	w.ball(Vector3(1.20,1.02,0.13),Vector3.ONE*0.045,"bca77a",pivot)
	for dx in [-0.82,0.82]: w.box(pos+Vector3(dx,1.1,0),Vector3(0.15,2.2,0.23),"d1c19a",parent)
	var marker: Label3D=w.sign_text("ДВЕРЬ",pos+Vector3(0,2.3,0.20),26,Color("e6d39a"))
	marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker.outline_size=6
	marker.outline_modulate=Color("243027")
	marker.visible=false
	g.doors[cell]={"cell":cell,"open":false,"pivot":pivot,"marker":marker}
