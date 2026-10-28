extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.start_match(0)
	game.menu_camera.current=true; game.menu_camera.position=Vector3(48,17,54); game.menu_camera.look_at(Vector3(0,3,0))
	for i in range(60): await process_frame
	var samples: Array[float]=[]
	var begin := Time.get_ticks_usec(); var previous := begin
	for i in range(300):
		await process_frame
		var now := Time.get_ticks_usec(); samples.append((now-previous)/1000.0); previous=now
	samples.sort()
	print("BENCHMARK: resolution=1280x720 actors=",game.actors.size()," wall_fps=",300000000.0/(Time.get_ticks_usec()-begin)," median_ms=",samples[150]," p95_ms=",samples[285])
	print("RENDER: draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	game.free(); OS.delay_msec(100); quit()
