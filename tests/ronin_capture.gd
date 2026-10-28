extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.start_match(0)
	game.menu.root.hide(); game.hud.set_process(false); game.hud.root.hide()
	for actor in game.actors: actor.set_physics_process(false)
	var bot: BotController=game.actors[5]
	bot.position=Vector3(0,0.001,26); bot.rotation.y=PI
	var camera: Camera3D=game.menu_camera; camera.current=true
	camera.position=Vector3(2.6,1.3,29.2); camera.look_at(bot.position+Vector3(0,1,0)); camera.fov=42
	for i in range(90): bot.weapons.tick(1.0/60); bot.visual.tick(1.0/60,0,false,bot.weapons); await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/ronin-musket.png")
	camera.position=Vector3(0,1.7,27.1); camera.look_at(bot.position+Vector3(0,1.69,0)); camera.fov=38
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/ronin-face.png")
	camera.position=Vector3(2.6,1.3,29.2); camera.look_at(bot.position+Vector3(0,1,0)); camera.fov=42
	for i in range(60): bot.visual.tick(1.0/60,0,true,bot.weapons); await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/ronin-crouch.png")
	bot.visual.reset_pose()
	bot.weapons.switch_weapon()
	for i in range(60): bot.weapons.tick(1.0/60); bot.visual.tick(1.0/60,0,false,bot.weapons); await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/ronin-katana.png")
	game.start_match(1)
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/ronin-first-person.png")
	game.free(); OS.delay_msec(100); quit()
