extends Control
var game: Node
func _draw():
	if not is_instance_valid(game): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("161d19"))
	var scale_v: Vector2 = size / Vector2(game.W,game.H)
	draw_rect(Rect2(Vector2(0,11)*scale_v,Vector2(game.W,4)*scale_v),Color("4b4b37"))
	for cell in game.solid:
		draw_rect(Rect2(Vector2(cell)*scale_v,scale_v),Color("938060"))
	for cell in game.cover:
		draw_rect(Rect2(Vector2(cell)*scale_v,scale_v),Color("655e45"))
	for unit in game.units:
		if unit.hp <= 0: continue
		var pos: Vector2 = (Vector2(unit.cell)+Vector2(0.5,0.5))*scale_v
		draw_circle(pos,3.5,Color("e1b868") if unit.team==0 else Color("dd6551"))
		if unit == game.selected: draw_arc(pos,6,0,TAU,24,Color.WHITE,1)
	draw_rect(Rect2(Vector2.ZERO,size),Color("655e45"),false,1)
