extends SceneTree
## Reproducible staged animation showcase followed by an autonomous live match.
var game: Node3D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.start_match(0)
	var p: PlayerController=game.player
	p.set_physics_process(false); p.position=Vector3(0,0.1,3)
	var bot: BotController=game.actors[4]
	for actor in game.actors:
		if actor!=p: actor.set_physics_process(false); actor.position=Vector3(17,0.1,17)
	bot.position=Vector3(0,0.1,-2); bot.rotation.y=PI
	var caption: Label= game.hud.label("ANIMATION SHOWCASE · STAGED",20,Vector2(430,125),Vector2(500,40))
	for frame in range(720):
		var delta := 1.0/30.0
		if frame<540:
			p.weapons.tick(delta)
			if frame<90:
				bot.position.x=sin(frame*0.04)*0.8
				bot.visual.tick(delta,3.2,false,bot.weapons)
			elif frame<150:
				bot.visual.tick(delta,0,true,bot.weapons)
			elif frame<180:
				bot.visual.tick(delta,0,false,bot.weapons)
			if frame==180:
				bot.position.x=0; bot.visual.reset_pose(); bot.head_hitbox.position.y=1.64
			if frame==185:
				p.weapons.attack(p.camera.global_position,(bot.global_position+Vector3(0,1.64,0)-p.camera.global_position).normalized())
			if bot.health.value<=0:
				bot.visual.tick(delta,0,false,bot.weapons); bot.dead_time-=delta
				if bot.dead_time<=0:
					bot.respawn(); bot.position=Vector3(0,0.1,0.8)
			if frame==350: p.weapons.switch_weapon()
			if frame==380 or frame==415:
				p.weapons.attack(p.camera.global_position,(bot.global_position+Vector3(0,1.2,0)-p.camera.global_position).normalized())
			if frame==450:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/animation-death.png")
		if frame==540:
			game.start_match(0); game.player.position=Vector3(0,0.1,10)
			caption.text="LIVE MATCH · AUTONOMOUS BOTS"
		if frame==660:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/animation-match.png")
		await process_frame
	game.free(); OS.delay_msec(100)
	quit()
