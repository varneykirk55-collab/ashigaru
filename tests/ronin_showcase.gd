extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.start_match(0)
	for actor in game.actors: actor.set_physics_process(false)
	var bot: BotController=game.actors[5]; bot.health.protection=0; bot.position=Vector3(0,0.025,27); bot.rotation.y=PI
	var camera: Camera3D=game.menu_camera; camera.current=true; camera.fov=48
	var caption: Label=game.hud.label("RŌNIN · AUTHORED ANIMATION SHOWCASE (STAGED)",18,Vector2(280,125),Vector2(750,35))
	for frame in range(1320):
		var dt := 1.0/30
		if frame<660:
			var speed := 0.0
			if frame>=45 and frame<105: speed=0.839
			if frame>=105 and frame<165: speed=3.2
			bot.position.z+=speed*dt
			bot.weapons.tick(dt)
			if frame==180: bot.weapons.attack(bot.position+Vector3(0,1.4,0),-bot.global_basis.z)
			if frame==345: bot.weapons.switch_weapon()
			if frame==375 or frame==405: bot.weapons.attack(bot.position+Vector3(0,1.4,0),-bot.global_basis.z)
			if frame==450: DamageSystem.hit(bot,10,game.player)
			if frame==495: DamageSystem.hit(bot,100,game.player)
			bot.visual.tick(dt,speed,false,bot.weapons)
			if bot.health.value<=0:
				bot.dead_time-=dt
				if bot.dead_time<=0 and bot.visual.death_finished:
					bot.respawn(); bot.position=Vector3(0,0.025,27); bot.rotation.y=PI; bot.health.protection=0
			camera.position=bot.position+Vector3(2.6,1.3,3.2); camera.look_at(bot.position+Vector3(0,0.9,0))
		if frame==660:
			game.start_match(0); camera.current=true; camera.fov=65
		if frame>=660:
			var followed: BotController=game.actors[5]
			for actor in game.actors:
				if actor is BotController and actor.team==1 and actor.health.value>0 and game.arena.districts.palace.has_point(Vector2(actor.position.x,actor.position.z)):
					followed=actor; break
			var focus: Vector3=followed.global_position+Vector3(0,1.1,0)
			var desired: Vector3=focus+followed.global_basis.z*4+followed.global_basis.x*2+Vector3(0,0.7,0)
			var q := PhysicsRayQueryParameters3D.create(focus,desired,1); q.exclude=[followed.get_rid()]
			var hit := game.get_world_3d().direct_space_state.intersect_ray(q)
			if hit: desired=hit.position+hit.normal*0.25
			camera.position=desired; camera.look_at(focus)
			caption.text="LIVE 5v5 · IMPORTED RŌNIN / ORIGINAL SAMURAI"
		await process_frame
	game.free(); OS.delay_msec(100); quit()
