extends RefCounted

func car(w: Node, game: Node, cell: Vector2i, color: String, wreck: bool):
	for x in range(cell.x,cell.x+2): game.cover[Vector2i(x,cell.y)]=true
	var p: Vector3=game.to_world(cell)+Vector3(0.8,0,0)
	w.box(p+Vector3(0,0.55,0),Vector3(3.9,0.38,1.62),color)
	w.box(p+Vector3(0,0.82,0),Vector3(3.68,0.25,1.54),color)
	w.box(p+Vector3(-0.24,1.03,0),Vector3(1.74,0.33,1.48),color)
	w.box(p+Vector3(-0.24,1.32,0),Vector3(1.52,0.48,1.40),"293b39")
	w.box(p+Vector3(-0.24,1.59,0),Vector3(1.70,0.08,1.50),color)
	# Sloping windshield and rear glass, with pillars and window seals.
	for direction in [-1,1]:
		var windshield: MeshInstance3D=w.box(p+Vector3(-0.24+direction*0.84,1.29,0),Vector3(0.045,0.57,1.33),"344943")
		windshield.rotation.z=direction*0.43
		for z in [-0.70,0.70]:
			w.rod(p+Vector3(-0.24+direction*0.98,1.04,z),p+Vector3(-0.24+direction*0.73,1.57,z),0.045,color)
		w.box(p+Vector3(-0.24,1.32,direction*0.718),Vector3(0.07,0.50,0.04),color)
		w.box(p+Vector3(-0.24,1.03,direction*0.77),Vector3(1.80,0.035,0.025),"a6a596")
		for x in [-0.68,0.26]:
			w.box(p+Vector3(x,0.83,direction*0.792),Vector3(0.23,0.045,0.045),"90968b")
		w.box(p+Vector3(-0.20,0.61,direction*0.82),Vector3(0.015,0.35,0.015),"414b3c")
		w.box(p+Vector3(0.60,1.10,direction*0.90),Vector3(0.20,0.15,0.18),color)
		w.box(p+Vector3(0.49,1.10,direction*0.90),Vector3(0.02,0.12,0.14),"a8b4a7")
	# Wheel faces and metallic hubs keep the silhouette readable at close range.
	for x in [-1.25,1.25]:
		for z in [-0.82,0.82]:
			var tire: MeshInstance3D=w.cylinder(p+Vector3(x,0.40,z),0.41,0.24,"242c27")
			tire.rotation.x=PI/2
			var hub: MeshInstance3D=w.cylinder(p+Vector3(x,0.40,z+signf(z)*0.135),0.25,0.025,"8b9388")
			hub.rotation.x=PI/2
			var cap: MeshInstance3D=w.cylinder(p+Vector3(x,0.40,z+signf(z)*0.155),0.10,0.035,"525d53")
			cap.rotation.x=PI/2
	for x in [-2,2]: w.box(p+Vector3(x,0.50,0),Vector3(0.13,0.17,1.72),"8a9285")
	w.box(p+Vector3(1.98,0.75,0),Vector3(0.04,0.20,0.72),"394439")
	for z in [-0.25,-0.12,0.0,0.12,0.25]: w.box(p+Vector3(2.01,0.75,z),Vector3(0.02,0.15,0.025),"adb09a")
	for z in [-0.57,0.57]:
		w.box(p+Vector3(1.98,0.78,z),Vector3(0.05,0.22,0.34),"d8cdae")
		w.box(p+Vector3(-1.98,0.75,z),Vector3(0.05,0.17,0.32),"8a4030")
	w.box(p+Vector3(-2.08,0.53,0),Vector3(0.018,0.13,0.40),"c3c3a6")
	w.box(p+Vector3(1.22,0.96,0),Vector3(0.92,0.025,1.39),"766a4d" if wreck else color)
	for z in [-0.45,-0.30,-0.15,0.0,0.15,0.30,0.45]: w.box(p+Vector3(0.77,0.98,z),Vector3(0.16,0.015,0.028),"4f5c4d")
	if wreck:
		for offset in [Vector3(-0.7,0.76,0.84),Vector3(1.2,0.73,0.84),Vector3(1.0,0.98,0.3)]:
			w.box(p+offset,Vector3(0.5,0.13,0.025) if offset.y<0.9 else Vector3(0.4,0.012,0.3),"785039")
		var hood: MeshInstance3D=w.box(p+Vector3(1.23,1.12,0),Vector3(0.95,0.045,1.40),color)
		hood.rotation.z=-0.23
		w.rod(p+Vector3(-0.4,1.40,0.73),p+Vector3(-0.1,1.14,0.73),0.012,"aab5a2")
	else:
		w.rod(p+Vector3(-1.4,0.95,-0.65),p+Vector3(-1.4,1.85,-0.65),0.008,"5c6b5d")
