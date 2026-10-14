extends RefCounted
const VERSION:=4
const DEFAULT_PATH:="res://../saves/quicksave.json"

func snapshot(game: Node) -> Dictionary:
	var roster: Array=[]
	for u in game.units:
		var record: Dictionary={}
		for key in ["id","hp","ap","ammo","reserve","medkits","grenades","watch","crouched"]: record[key]=u[key]
		record.cell=[u.cell.x,u.cell.y]
		record.alert=[u.alert.x,u.alert.y]
		roster.append(record)
	var visited: Array=[]
	for cell in game.tactics.explored: visited.append([cell.x,cell.y])
	var reveals: Array=[]
	for id in game.tactics.revealed: reveals.append([id,game.tactics.revealed[id]])
	var door_states: Array=[]
	for cell in game.doors: door_states.append([cell.x,cell.y,game.doors[cell].open])
	var barrel_states: Array=[]
	for cell in game.explosives.barrels: barrel_states.append([cell.x,cell.y,game.explosives.barrels[cell].intact])
	return {"barrels":barrel_states,"doors":door_states,"version":VERSION,"turn":game.turn,"units":roster,"selected":game.selected.id,"rng_state":str(game.rng.state),"rng_seed":str(game.rng.seed),"explored":visited,"revealed":reveals,"shots":game.tactics.shots,"hits":game.tactics.hits,"camera":[game.camera_target.x,game.camera_target.z,game.yaw,game.zoom]}

func save_game(game: Node, path: String=DEFAULT_PATH) -> String:
	if game.busy or game.won: return "Сохранять можно в свой ход, пока операция не закончена."
	var absolute:=ProjectSettings.globalize_path(path)
	var error:=DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error!=OK: return "Не удалось создать папку сохранений."
	var file:=FileAccess.open(absolute+".tmp",FileAccess.WRITE)
	if file==null: return "Не удалось записать сохранение."
	file.store_string(JSON.stringify(snapshot(game),"\t"))
	file.close()
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK: return "Не удалось заменить файл сохранения."
	return ""

func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value))==float(value) and float(value)>=minimum and float(value)<=maximum

func valid_cell(value: Variant, game: Node, allow_unknown: bool=false) -> bool:
	if not value is Array or value.size()!=2: return false
	if allow_unknown and integer(value[0],-1,-1) and integer(value[1],-1,-1): return true
	return integer(value[0],0,game.W-1) and integer(value[1],0,game.H-1)

func validate(data: Variant, game: Node) -> String:
	if not data is Dictionary: return "Некорректный формат сохранения."
	if data.get("version")!=VERSION: return "Версия сохранения не поддерживается."
	if not integer(data.get("turn"),1,10000) or not integer(data.get("selected"),0,2): return "Повреждены параметры хода."
	if not data.get("units") is Array or data.units.size()!=game.units.size(): return "Повреждён состав отряда."
	if not data.get("doors") is Array or data.doors.size()!=game.doors.size(): return "Повреждены двери."
	var saved_doors: Dictionary={}
	for door in data.doors:
		if not door is Array or door.size()!=3 or not valid_cell([door[0],door[1]],game) or not door[2] is bool: return "Повреждена дверь."
		var cell:=Vector2i(int(door[0]),int(door[1]))
		if not game.doors.has(cell) or saved_doors.has(cell): return "Неизвестная или повторяющаяся дверь."
		saved_doors[cell]=door[2]
	if not data.get("barrels") is Array or data.barrels.size()!=game.explosives.barrels.size(): return "Повреждены данные бочек."
	var saved_barrels: Dictionary={}
	for barrel in data.barrels:
		if not barrel is Array or barrel.size()!=3 or not valid_cell([barrel[0],barrel[1]],game) or not barrel[2] is bool: return "Повреждено состояние бочки."
		var cell:=Vector2i(int(barrel[0]),int(barrel[1]))
		if not game.explosives.barrels.has(cell) or saved_barrels.has(cell): return "Неизвестная или повторяющаяся бочка."
		saved_barrels[cell]=barrel[2]
	var occupied: Dictionary={}
	for i in range(data.units.size()):
		var u: Variant=data.units[i]
		if not u is Dictionary or u.get("id")!=i: return "Неверный идентификатор бойца."
		var bounds: Dictionary={"hp":100,"ap":game.MAX_AP,"ammo":game.units[i].capacity,"reserve":game.units[i].capacity*2,"medkits":2,"grenades":1}
		for key in bounds:
			if not integer(u.get(key),0,bounds[key]): return "Некорректное значение: "+key
		if not u.get("watch") is bool or not u.get("crouched") is bool: return "Повреждена поза бойца."
		if not valid_cell(u.get("cell"),game) or not valid_cell(u.get("alert"),game,true): return "Координаты вне карты."
		var cell:=Vector2i(int(u.cell[0]),int(u.cell[1]))
		if u.hp>0:
			if occupied.has(cell) or (game.solid.has(cell) and not game.doors.has(cell)) or (saved_doors.has(cell) and not saved_doors[cell]) or (game.cover.has(cell) and not saved_barrels.has(cell)) or (saved_barrels.has(cell) and saved_barrels[cell]): return "Боец находится в занятой клетке."
			occupied[cell]=true
	if data.units[int(data.selected)].hp<=0: return "Выбран выбывший боец."
	for key in ["rng_state","rng_seed"]:
		if not data.get(key) is String or not data[key].is_valid_int(): return "Повреждено состояние генератора."
	for key in ["shots","hits"]:
		if not integer(data.get(key),0,1000000): return "Повреждена статистика."
	if not data.get("explored") is Array or data.explored.size()>game.W*game.H: return "Повреждены данные разведки."
	for cell in data.explored:
		if not valid_cell(cell,game): return "Повреждена карта разведки."
	if not data.get("revealed") is Array or data.revealed.size()>game.units.size(): return "Повреждены контакты."
	for item in data.revealed:
		if not item is Array or item.size()!=2 or not integer(item[0],0,game.units.size()-1) or not integer(item[1],0,10001): return "Повреждено время контакта."
	if not data.get("camera") is Array or data.camera.size()!=4: return "Повреждена камера."
	for value in data.camera:
		if not (value is int or value is float) or not is_finite(float(value)): return "Повреждена камера."
	return ""

func load_game(game: Node, path: String=DEFAULT_PATH) -> String:
	if game.busy: return "Дождитесь завершения действия."
	if not FileAccess.file_exists(path): return "Сохранения пока нет. [F5] — сохранить."
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>131072: return "Не удалось прочитать сохранение."
	var parser:=JSON.new()
	var parse_error:=parser.parse(file.get_as_text())
	file.close()
	if parse_error!=OK: return "Файл сохранения повреждён; текущая игра не изменена."
	var data: Variant=parser.data
	var error:=validate(data,game)
	if error!="": return error
	# Apply only after the entire payload has passed validation.
	game.clear_path()
	if is_instance_valid(game.outcome_panel):
		game.outcome_panel.queue_free()
		game.outcome_panel=null
	game.won=false
	game.enemy_turn=false
	game.aimed=false
	game.turn=int(data.turn)
	for door in data.doors: game.set_door_state(Vector2i(int(door[0]),int(door[1])),door[2])
	for barrel in data.barrels: game.explosives.set_intact(Vector2i(int(barrel[0]),int(barrel[1])),barrel[2])
	for i in range(data.units.size()):
		var saved: Dictionary=data.units[i]
		var unit: Dictionary=game.units[i]
		if unit.has("death_tween") and is_instance_valid(unit.death_tween): unit.death_tween.kill()
		for key in ["hp","ap","ammo","reserve","medkits","grenades"]: unit[key]=int(saved[key])
		for key in ["watch","crouched"]: unit[key]=saved[key]
		unit.cell=Vector2i(int(saved.cell[0]),int(saved.cell[1]))
		unit.alert=Vector2i(int(saved.alert[0]),int(saved.alert[1]))
		unit.node.position=game.to_world(unit.cell)
		unit.node.rotation=Vector3(0,PI if unit.team==1 else 0,PI/2 if unit.hp==0 else 0)
		unit.node.scale=Vector3(1,0.74 if unit.crouched else 1.0,1)
	game.selected=game.units[int(data.selected)]
	game.rng.seed=data.rng_seed.to_int()
	game.rng.state=data.rng_state.to_int()
	game.tactics.mode="normal"
	game.tactics.explored.clear()
	for cell in data.explored: game.tactics.explored[Vector2i(int(cell[0]),int(cell[1]))]=true
	game.tactics.revealed.clear()
	for item in data.revealed: game.tactics.revealed[int(item[0])]=int(item[1])
	game.tactics.kills=0
	for u in game.units:
		if u.team==1 and u.hp<=0: game.tactics.kills+=1
	game.tactics.shots=int(data.shots)
	game.tactics.hits=int(data.hits)
	game.camera_target=Vector3(clampf(data.camera[0],-25,25),0,clampf(data.camera[1],-20,20))
	game.yaw=fposmod(data.camera[2],TAU)
	game.zoom=clampf(data.camera[3],18,68)
	game.tactics.update_visibility()
	game.ui_invalidate()
	game.refresh_ui()
	return ""
