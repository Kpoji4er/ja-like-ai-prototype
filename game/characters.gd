extends RefCounted
var w: Node

func capsule(pos: Vector3, radius: float, height: float, color: String, parent: Node) -> MeshInstance3D:
	var mesh:=CapsuleMesh.new()
	mesh.radius=radius
	mesh.height=height
	mesh.radial_segments=12
	mesh.rings=4
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=w.mat(color)
	parent.add_child(node)
	node.position=pos
	return node

func build(world: Node, team: int, index: int) -> Node3D:
	w=world
	var root:=Node3D.new()
	var uniform: String=["626e45","657b63","586b59"][index%3] if team==0 else "89513c"
	var trousers: String="48513b" if team==0 else "53533a"
	var skin: String=["b58c6a","d4a382","79583e"][index%3]
	var hair: String=["40352b","654932","2c3027"][index%3]
	# Legs pivot from the hips, so procedural strides bend naturally.
	for side in [-1,1]:
		var leg:=Node3D.new()
		leg.name="LegL" if side==-1 else "LegR"
		root.add_child(leg)
		leg.position=Vector3(side*0.145,0.86,0)
		capsule(Vector3(0,-0.20,0),0.13,0.48,trousers,leg)
		capsule(Vector3(0,-0.53,0.015),0.105,0.39,trousers,leg)
		w.ball(Vector3(0,-0.37,-0.065),Vector3(0.12,0.13,0.09),"555b3c",leg)
		w.box(Vector3(side*0.09,-0.18,0.02),Vector3(0.10,0.21,0.18),"646b48",leg)
		w.ball(Vector3(0,-0.75,-0.045),Vector3(0.125,0.115,0.22),"30352a",leg)
		w.box(Vector3(0,-0.835,-0.06),Vector3(0.25,0.045,0.37),"242c24",leg)
	# Tailored torso, neck and shoulder forms rather than a single box.
	w.ball(Vector3(0,1.08,0.015),Vector3(0.31,0.36,0.20),uniform,root)
	w.cylinder(Vector3(0,1.43,0),0.095,0.17,skin,root)
	w.box(Vector3(0,0.86,0),Vector3(0.45,0.09,0.33),"343c2c",root)
	w.box(Vector3(0,0.86,-0.17),Vector3(0.07,0.07,0.035),"9d9270",root)
	w.box(Vector3(0,1.12,-0.14),Vector3(0.45,0.48,0.16),"444e35",root)
	w.box(Vector3(0,1.13,0.23),Vector3(0.40,0.43,0.21),"525b3c",root)
	for side in [-1,1]:
		w.box(Vector3(side*0.19,1.31,-0.08),Vector3(0.09,0.29,0.13),"78805a",root)
		w.ball(Vector3(side*0.31,1.27,0),Vector3(0.13,0.14,0.15),uniform,root)
		w.box(Vector3(side*0.20,0.99,-0.25),Vector3(0.15,0.21,0.10),"74794e",root)
	w.box(Vector3(0,1.0,-0.25),Vector3(0.15,0.21,0.11),"686e46",root)
	# Rounded head with face planes, ears, eyes and individual hair/headgear.
	w.ball(Vector3(0,1.65,0),Vector3(0.175,0.215,0.16),skin,root)
	w.ball(Vector3(0,1.52,-0.012),Vector3(0.135,0.10,0.127),skin,root)
	for side in [-1,1]:
		w.ball(Vector3(side*0.177,1.64,0.003),Vector3(0.037,0.061,0.032),skin,root)
		w.ball(Vector3(side*0.072,1.68,-0.143),Vector3(0.038,0.018,0.013),"d7d2b7",root)
		w.ball(Vector3(side*0.072,1.679,-0.154),Vector3(0.013,0.014,0.008),"343e31",root)
		var brow: MeshInstance3D=w.box(Vector3(side*0.075,1.714,-0.141),Vector3(0.074,0.014,0.015),hair,root)
		brow.rotation.z=side*0.08
	w.ball(Vector3(0,1.629,-0.161),Vector3(0.032,0.054,0.047),skin,root)
	w.box(Vector3(0,1.545,-0.126),Vector3(0.077,0.012,0.018),"795745",root)
	if team==0 and index==0:
		var beret: MeshInstance3D=w.ball(Vector3(0.018,1.819,0.014),Vector3(0.22,0.10,0.20),"703e35",root)
		beret.rotation.z=-0.16
		w.cylinder(Vector3(0,1.77,0),0.179,0.035,"343a2c",root)
		w.box(Vector3(-0.073,1.803,-0.172),Vector3(0.032,0.04,0.02),"c3b47a",root)
		w.box(Vector3(0,1.577,-0.145),Vector3(0.105,0.025,0.019),hair,root)
	elif team==0 and index==1:
		w.ball(Vector3(0,1.80,0.027),Vector3(0.18,0.10,0.17),hair,root)
		w.ball(Vector3(0,1.65,0.16),Vector3(0.15,0.18,0.06),hair,root)
		capsule(Vector3(0.035,1.46,0.21),0.07,0.27,hair,root)
		w.box(Vector3(0,1.79,-0.07),Vector3(0.30,0.025,0.07),"3c4532",root)
	else:
		w.ball(Vector3(0,1.80,0.01),Vector3(0.20,0.11,0.18),"414f39" if team==0 else "635137",root)
		w.box(Vector3(0,1.762,-0.18),Vector3(0.28,0.025,0.16),"414f39" if team==0 else "635137",root)
	# A small radio and sling give readable silhouettes at game distance.
	w.box(Vector3(-0.22,1.27,0.20),Vector3(0.10,0.20,0.10),"303c2d",root)
	w.rod(Vector3(-0.22,1.36,0.20),Vector3(-0.22,1.65,0.20),0.012,"343e2b",root)
	w.rod(Vector3(-0.22,1.35,-0.15),Vector3(0.20,0.90,-0.21),0.025,"8b8157",root)
	# Bent sleeves and exposed forearms hold a weapon across the chest.
	w.rod(Vector3(-0.32,1.26,0),Vector3(-0.33,1.02,-0.22),0.095,uniform,root)
	w.rod(Vector3(-0.33,1.02,-0.22),Vector3(-0.09,1.12,-0.59),0.065,skin,root)
	w.rod(Vector3(0.33,1.26,0),Vector3(0.36,1.02,-0.20),0.095,uniform,root)
	w.rod(Vector3(0.36,1.02,-0.20),Vector3(0.08,1.10,-0.31),0.065,skin,root)
	w.ball(Vector3(-0.09,1.12,-0.59),Vector3(0.055,0.045,0.08),skin,root)
	w.ball(Vector3(0.08,1.10,-0.31),Vector3(0.055,0.06,0.045),skin,root)
	var wood: String="6b4c30" if index%3!=1 else "343b32"
	var length: float=0.72 if index%3==1 else (0.98 if index%3==0 else 1.1)
	w.box(Vector3(0.03,1.14,-0.44),Vector3(0.09,0.12,length*0.55),"2c332d",root)
	w.box(Vector3(0.03,1.12,-0.10),Vector3(0.105,0.14,0.29),wood,root)
	w.box(Vector3(0.03,1.135,-0.64),Vector3(0.11,0.10,0.25),wood,root)
	w.rod(Vector3(0.03,1.16,-0.70),Vector3(0.03,1.16,-length),0.026,"333b33",root)
	var magazine: MeshInstance3D=w.box(Vector3(0.03,0.99,-0.41),Vector3(0.075,0.22,0.115),"374037",root)
	magazine.rotation.x=-0.20 if index%3==0 else 0
	w.box(Vector3(0.03,1.225,-0.43),Vector3(0.045,0.025,0.24),"424a3d",root)
	w.batch_group(root)
	w.batch_group(root.get_node("LegL"))
	w.batch_group(root.get_node("LegR"))
	return root
