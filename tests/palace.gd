extends SceneTree
var game: Node3D
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+label)
	else: print("PASS: "+label)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames(3)
	check(game.arena.region.navigation_mesh.get_polygon_count()>0,"engine navmesh baked from palace collision")
	check(game.arena.navigation.region.size==Vector2i(147,147),"150 metre grounds have matching route grid")
	game.start_match(0)
	await frames(3)
	check(game.actors.size()==10,"ten combatants active")
	var p: PlayerController=game.player
	var enemy: BotController=game.actors[5]
	check(not DamageSystem.hit(p,100,enemy) and p.health.value==100,"spawn shield prevents incoming damage")
	var locations: Array[Vector3]=[]
	for actor in game.actors:
		locations.append(actor.global_position); actor.set_physics_process(false)
	var min_distance := INF
	for i in range(locations.size()):
		for j in range(i): min_distance=minf(min_distance,locations[i].distance_to(locations[j]))
	check(min_distance>1,"safe spawn slots do not overlap")
	p.weapons.attack(p.camera.global_position,Vector3.FORWARD)
	check(p.health.protection==0,"firing forfeits spawn shield")
	p.health.protection=1000
	p.global_position=Vector3(0,0.1,24)
	p.rotation.y=0; p.set_physics_process(true)
	var toggle := InputEventAction.new(); toggle.action="auto_sprint"; toggle.pressed=true
	p._unhandled_input(toggle)
	check(p.auto_sprint,"auto-sprint toggle is functional")
	var sprint_start: Vector3=p.global_position
	Input.action_press("forward"); await frames(60); Input.action_release("forward")
	check(p.global_position.distance_to(sprint_start)>6,"auto-sprint moves player at sprint speed without Shift")
	p.auto_sprint=false; p.set_physics_process(false); p.global_position=Vector3(0,0.1,24)
	var destinations := [Vector3(0,0,0),Vector3(16,0,12),Vector3(43,0,22),Vector3(-40,0,-48),Vector3(0,0,-24),Vector3(0,0,24)]
	for dest in destinations:
		var path: PackedVector3Array=game.arena.route(p.global_position,dest)
		check(not path.is_empty(),"connected palace/garden route to "+str(dest))
		var index := 1
		for step in range(2400):
			if index>=path.size(): break
			var offset := path[index]-p.global_position; offset.y=0
			if offset.length()<0.32: index+=1; continue
			p.velocity=offset.normalized()*7; p.velocity.y=-2; p.move_and_slide()
			await physics_frame
		check(index>=path.size(),"player physically traverses route without wall blockage to "+str(dest))
	var covered: Vector3=game.arena.reload_cover(Vector3(-18,0,34),Vector3(-18,0,25))
	var q := PhysicsRayQueryParameters3D.create(covered+Vector3.UP,Vector3(-18,1,25),1)
	check(covered.distance_to(Vector3(-18,0,34))>0.1 and not game.get_world_3d().direct_space_state.intersect_ray(q).is_empty(),"reload cover is reachable and blocks opponent sight")
	var r0: PackedVector3Array=game.arena.route(Vector3(-57,0,40),Vector3(-18,0,12))
	var r1: PackedVector3Array=game.arena.route(Vector3(-57,0,40),Vector3(18,0,12))
	check(r0!=r1,"flanking lanes produce distinct routes")
	# Exercise production bot decisions at two encounter ranges, not just weapon units.
	p.health.protection=0; p.health.reset(); p.position=Vector3(0,0.1,0)
	enemy.respawn(); enemy.health.protection=0; enemy.position=Vector3(0,0.1,-18)
	enemy.think=0; enemy.fire_delay=0; enemy.set_physics_process(true)
	await frames(90)
	print("RANGED DIAGNOSTIC: health=",p.health.value," loaded=",enemy.weapons.musket.loaded," target_player=",enemy.target==p," reload=",enemy.weapons.musket.remaining)
	check(enemy.target==p and not enemy.weapons.musket.loaded and enemy.weapons.musket.remaining>0,"bot aims and fires musket at an 18 metre encounter (spread may miss)")
	enemy.set_physics_process(false)
	p.respawn(); p.health.protection=0; p.position=Vector3(0,0.1,0)
	enemy.respawn(); enemy.health.protection=0; enemy.position=Vector3(0,0.1,-2)
	enemy.think=0; enemy.fire_delay=0; enemy.set_physics_process(true)
	await frames(150)
	check(p.health.value==0 and enemy.weapons.selected==1 and enemy.weapons.musket.loaded,"bot switches to katana and kills at close range without firing")
	game.start_match(0); game.match_state.score_limit=12; game.match_state.time_left=360
	await frames(18000)
	var visits := 0; var covers := 0
	for actor in game.actors:
		if actor is BotController:
			if actor.interior_visits>0: visits+=1
			covers+=actor.cover_selections
	check(visits>=4,"bots enter palace interiors during autonomous combat")
	check(covers>0,"bots select cover while reloading")
	check(game.match_state.scores[0]>0 and game.match_state.scores[1]>0,"both teams score on expanded battlefield")
	check(not game.match_state.active and game.menu.root.visible,"complete ten-combatant match reaches results")
	print("PALACE METRICS: scores=",game.match_state.scores," interior_bots=",visits," cover_choices=",covers)
	print("PALACE RESULT: %d checks, %d failures" % [checks,failures])
	game.free(); OS.delay_msec(100); quit(0 if failures==0 else 1)
