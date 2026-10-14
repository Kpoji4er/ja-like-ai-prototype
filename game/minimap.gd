extends Control
var game: Node
func _draw():
	if not is_instance_valid(game): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("161d19"))
	var scale_v: Vector2 = size / Vector2(game.W,game.H)
	if game.sector_index==1:
		draw_rect(Rect2(Vector2(14,0)*scale_v,Vector2(4,game.H)*scale_v),Color("4b4b37"))
	elif game.sector_index!=2:
		draw_rect(Rect2(Vector2(0,11)*scale_v,Vector2(game.W,4)*scale_v),Color("4b4b37"))
	for cell in game.solid:
		draw_rect(Rect2(Vector2(cell)*scale_v,scale_v),Color("938060"))
	for cell in game.cover:
		draw_rect(Rect2(Vector2(cell)*scale_v,scale_v),Color("655e45"))
	for unit in game.units:
		if unit.hp <= 0 or not unit.visible: continue
		var pos: Vector2 = (Vector2(unit.cell)+Vector2(0.5,0.5))*scale_v
		draw_circle(pos,3.5,Color("e1b868") if unit.team==0 else Color("dd6551"))
		if unit == game.selected: draw_arc(pos,6,0,TAU,24,Color.WHITE,1)
	for x in range(game.W):
		for y in range(game.H):
			var cell:=Vector2i(x,y)
			if not game.tactics.visible_cells.has(cell):
				draw_rect(Rect2(Vector2(cell)*scale_v,scale_v),Color(0.03,0.05,0.04,0.72 if not game.tactics.explored.has(cell) else 0.35))
	var goals: Array[Vector2i]=[]
	if game.campaign.index==1: goals.assign([game.campaign.civilian_cell,game.campaign.extraction])
	if game.campaign.index==2: goals.append(game.campaign.relay_cell)
	if game.campaign.index==3:
		for i in range(2):
			if not game.campaign.switches[i]: goals.append(game.campaign.terminals[i])
	for goal in goals:
		var pos: Vector2=(Vector2(goal)+Vector2(0.5,0.5))*scale_v
		draw_rect(Rect2(pos-Vector2(4,4),Vector2(8,8)),Color("9ee5b0"),false,2)
	draw_rect(Rect2(Vector2.ZERO,size),Color("655e45"),false,1)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var cell:=Vector2i(int(event.position.x/size.x*game.W),int(event.position.y/size.y*game.H))
		game.camera_target=game.to_world(cell)
		accept_event()
