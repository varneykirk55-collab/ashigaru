extends SceneTree
var game: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.menu.root.hide(); game.hud.root.hide()
	var camera: Camera3D=game.menu_camera
	var views := {"exterior":[Vector3(40,13,44),Vector3(0,5,0)],"interior":[Vector3(14,2.1,14),Vector3(19,1.1,10)],"courtyard":[Vector3(-20,2.2,49),Vector3(0,3,0)],"garden":[Vector3(-61,2.2,-50),Vector3(-44,1.2,-40)]}
	for key in views:
		camera.position=views[key][0]; camera.look_at(views[key][1])
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/palace-"+key+".png")
	if "--shots-only" in OS.get_cmdline_user_args():
		game.free(); quit(); return
	game.start_match(0)
	camera.current=true; camera.position=Vector3(-35,12,30); camera.look_at(Vector3(0,1,0))
	var caption: Label=game.hud.label("PALACE OF ASH · LIVE 5v5 BOT NAVIGATION",20,Vector2(350,125),Vector2(650,35))
	var followed: BotController=game.actors[1]
	for frame in range(1200):
		if frame%180==0 or followed.health.value<=0:
			for actor in game.actors:
				if actor is BotController and actor.health.value>0 and game.arena.districts.palace.has_point(Vector2(actor.position.x,actor.position.z)):
					followed=actor; break
			if followed.health.value<=0:
				for actor in game.actors:
					if actor is BotController and actor.health.value>0: followed=actor; break
		var focus: Vector3=followed.global_position+Vector3(0,1.2,0)
		var desired: Vector3=focus+followed.global_basis.z*4.0+followed.global_basis.x*1.7+Vector3(0,1.0,0)
		var ray := PhysicsRayQueryParameters3D.create(focus,desired,1); ray.exclude=[followed.get_rid()]
		var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit: desired=hit.position+hit.normal*0.25
		camera.global_position=desired; camera.look_at(focus)
		caption.text="LIVE BOT FOLLOW · PALACE INTERIOR" if game.arena.districts.palace.has_point(Vector2(followed.position.x,followed.position.z)) else "LIVE BOT FOLLOW · EXTERIOR APPROACH"
		await process_frame
	game.free(); OS.delay_msec(100); quit()
