extends RefCounted

func palm(world: Node, p: Vector3, height: float):
	var top:=p+Vector3(0.38,height,0.12)
	for i in range(12):
		var t0:=i/12.0
		var t1:=(i+1)/12.0
		var a:=p+Vector3(0.38*t0*t0,height*t0,0.12*t0)
		var b:=p+Vector3(0.38*t1*t1,height*t1,0.12*t1)
		world.rod(a,b,lerpf(0.25,0.14,t0),["736047","826d4e","6f5e44"][i%3])
		world.cylinder(b,lerpf(0.26,0.15,t1),0.06,"554e37")
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in range(11):
		var angle:=TAU*frond/11.0+height*0.2
		var outward:=Vector3(cos(angle),0,sin(angle))
		var side:=Vector3(-outward.z,0,outward.x)
		var length:=3.0+sin(frond*2.7)*0.5
		var previous:=top
		for segment in range(1,12):
			var t:=segment/11.0
			var center:=top+outward*length*t+Vector3.UP*(sin(t*PI)*0.65-t*t*1.25)
			world.rod(previous,center,0.025*(1-t)+0.008,"7b8047")
			previous=center
			var leaf_length:=sin(t*PI)*0.85+0.10
			for direction in [-1,1]:
				var base:=center-outward*0.09
				var tip: Vector3=center+side*direction*leaf_length+outward*0.24-Vector3.UP*leaf_length*0.3
				var middle: Vector3=base.lerp(tip,0.48)+Vector3.UP*0.065
				var width:=outward*0.11
				surface.set_color(Color(["536a34","687d40","405c30"][(frond+segment)%3]))
				for vertex in [base,middle-width,middle+width,middle-width,tip,middle+width]: surface.add_vertex(vertex)
	for i in range(4):
		var angle:=i*TAU/4
		world.ball(top+Vector3(cos(angle)*0.18,-0.20,sin(angle)*0.18),Vector3(0.16,0.21,0.16),"6b7041")
	surface.generate_normals()
	var foliage:=MeshInstance3D.new()
	foliage.mesh=surface.commit()
	var material:=ShaderMaterial.new()
	material.shader=load("res://leaves.gdshader")
	material.set_shader_parameter("use_vertex_color",true)
	foliage.material_override=material
	world.add_child(foliage)
