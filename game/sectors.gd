extends RefCounted
## Three distinct layouts in addition to the original Omerta checkpoint.
func build(w: Node, g: Node, mission: int):
	w.rng.seed=700+mission
	if mission==1:
		w.building(Vector2i(21,3),Vector2i(7,7),"d4ccb0","SAN MIGUEL / CLINICA",true)
		w.building(Vector2i(6,3),Vector2i(6,6),"c8a282","CASA DE MARIA",false)
		w.building(Vector2i(11,17),Vector2i(6,6),"b9b78f","MERCADO",false)
		w.building(Vector2i(22,17),Vector2i(6,6),"bc937b","TALLER",false)
		for cell in [Vector2i(8,12),Vector2i(9,12),Vector2i(13,10),Vector2i(14,10),Vector2i(20,14),Vector2i(21,14),Vector2i(28,10)]: w.low_wall(cell)
		w.car(Vector2i(18,10),"a19e7b",false)
		w.car(Vector2i(8,20),"83604a",true)
		# Central village well and market stalls are real cover.
		var cell:=Vector2i(12,12)
		g.cover[cell]=true
		var p: Vector3=g.to_world(cell)
		w.cylinder(p+Vector3.UP*0.5,0.85,1.0,"9e9273")
		for dx in [-0.8,0.8]: w.rod(p+Vector3(dx,0,0),p+Vector3(dx,2.4,0),0.07,"6e5039")
		w.box(p+Vector3.UP*2.4,Vector3(2.3,0.18,2),"9f674a")
		for cell2 in [Vector2i(19,20),Vector2i(19,22)]:
			g.cover[cell2]=true
			var q: Vector3=g.to_world(cell2)
			w.box(q+Vector3.UP*0.6,Vector3(1.4,1.2,1),"796346")
			w.box(q+Vector3.UP*2,Vector3(2.1,0.1,1.9),"b98a50")
	elif mission==2:
		w.building(Vector2i(6,8),Vector2i(7,6),"899481","RADIO / B10",false)
		w.building(Vector2i(23,3),Vector2i(6,5),"96967d","GENERATOR",false)
		for cell in [Vector2i(7,16),Vector2i(7,17),Vector2i(13,16),Vector2i(13,17),Vector2i(9,19),Vector2i(11,19),Vector2i(16,9),Vector2i(17,9),Vector2i(22,18),Vector2i(23,18)]: w.sandbags(cell)
		w.car(Vector2i(18,21),"55644d",true)
		# A lattice antenna makes the hill station identifiable from any angle.
		var cell:=Vector2i(10,5)
		g.cover[cell]=true
		var p: Vector3=g.to_world(cell)
		for dx in [-0.8,0.8]:
			for dz in [-0.8,0.8]: w.rod(p+Vector3(dx,0,dz),p+Vector3(dx*0.25,10,dz*0.25),0.065,"687167")
		for i in range(5):
			var y: float=i*2.0
			w.rod(p+Vector3(-0.7,y,-0.7),p+Vector3(0.7,y+2,-0.7),0.04,"8b8f7e")
			w.rod(p+Vector3(0.7,y,0.7),p+Vector3(-0.7,y+2,0.7),0.04,"8b8f7e")
		w.ball(p+Vector3(0,9.6,-0.5),Vector3(1.2,1.2,0.2),"b3b3a0")
		w.cylinder(p+Vector3.UP*10.8,0.09,1.6,"b98568")
	else:
		w.building(Vector2i(21,3),Vector2i(7,7),"989b8a","COMANDANCIA",false)
		w.building(Vector2i(11,3),Vector2i(7,6),"9b927b","ARSENAL",false)
		w.building(Vector2i(20,15),Vector2i(7,5),"a59c7f","BARRACAS",false)
		# Compound perimeter with two entrances; interior walls split the approach.
		for x in range(9,30):
			if x not in [14,15,25,26]: w.low_wall(Vector2i(x,23))
		for y in range(2,23):
			if y not in [11,12,13,20]: w.low_wall(Vector2i(9,y))
		for cell in [Vector2i(14,18),Vector2i(15,18),Vector2i(16,14),Vector2i(17,14),Vector2i(20,10),Vector2i(28,14),Vector2i(28,15)]: w.sandbags(cell)
		w.car(Vector2i(12,20),"4c5e4b",false)
		w.car(Vector2i(25,11),"58674e",false)
		for cell in [Vector2i(12,10),Vector2i(13,10),Vector2i(28,20)]:
			g.cover[cell]=true
			w.box(g.to_world(cell)+Vector3.UP*0.9,Vector3(1.5,1.8,1.5),"56654b")
	# Deterministic vegetation and boundary hills, different for every sector.
	for i in range(100):
		var p:=Vector3(w.rng.randf_range(-34,34),0,w.rng.randf_range(-28,28))
		var cell: Vector2i=g.to_cell(p)
		if g.solid.has(cell) or g.cover.has(cell) or w.interior_cell(cell): continue
		if (mission==1 and abs(p.x)<4.5) or (mission==3 and abs(p.z)<4.5): continue
		w.bush(p,w.rng.randf_range(0.35,0.8))
	for p in [Vector3(-27,0,-18),Vector3(28,0,20),Vector3(-26,0,20),Vector3(5,0,-21)]: w.palm(p,5.0+mission*0.3)
	for i in range(16):
		var angle: float=i*TAU/16.0
		w.ball(Vector3(cos(angle)*43,-2,sin(angle)*36),Vector3(9,4+mission,7),"65704d" if mission==2 else "7a7454")
