extends MeshInstance3D
## Optional reachability aid. Green retains a shot; amber spends the whole turn.
var game: Node
var enabled:=false

func initialize(owner_game: Node):
	game=owner_game
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test=false
	material_override=material

func rebuild():
	visible=enabled and not game.busy and not game.won and not game.cinematic
	if not visible: return
	var actor: Dictionary=game.selected
	var available: int=actor.ap+(6 if actor.watch else 0)
	var routes: Dictionary=game.reachable_routes(actor,available/2)
	if routes.size()<2:
		mesh=null
		return
	var surface:=ImmediateMesh.new()
	surface.surface_begin(Mesh.PRIMITIVE_LINES)
	for cell in routes:
		if cell==actor.cell: continue
		var cost: int=(routes[cell].size()-1)*2
		var retains_shot: bool=available-cost>=6
		surface.surface_set_color(Color(0.20,0.76,0.40,0.85) if retains_shot else Color(0.98,0.58,0.11,0.85))
		var center: Vector3=game.to_world(cell)+Vector3.UP*0.075
		var half: float=game.C*0.43
		var corners: Array[Vector3]=[Vector3(-half,0,-half),Vector3(half,0,-half),Vector3(half,0,half),Vector3(-half,0,half)]
		for i in range(4):
			var a: Vector3=center+corners[i]
			var b: Vector3=center+corners[(i+1)%4]
			surface.surface_add_vertex(a)
			surface.surface_add_vertex(b if retains_shot else a.lerp(b,0.32))
			if not retains_shot:
				surface.surface_add_vertex(a.lerp(b,0.68))
				surface.surface_add_vertex(b)
	surface.surface_end()
	mesh=surface
