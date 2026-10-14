extends RefCounted

func run(game: Node):
	await game.get_tree().create_timer(3).timeout
	var samples: Array[float]=[]
	var draw_calls: Array[float]=[]
	var previous:=Time.get_ticks_usec()
	var start:=previous
	while Time.get_ticks_usec()-start<6000000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous=now
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	samples.sort()
	var total:=0.0
	for sample in samples: total+=sample
	var calls:=0.0
	for count in draw_calls: calls+=count
	var report: Dictionary={"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(game.get_viewport().get_visible_rect().size),"frames":samples.size(),"mean_frame_ms":total/samples.size(),"p95_frame_ms":samples[int(samples.size()*0.95)],"mean_draw_calls":calls/draw_calls.size(),"scope":"Static initial sector after 3 seconds warmup; local machine only."}
	var file:=FileAccess.open("res://../build/performance.json",FileAccess.WRITE)
	report.render_resolution=str(game.get_viewport().get_texture().get_size())
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PERFORMANCE: "+JSON.stringify(report))
	game.get_tree().quit()
