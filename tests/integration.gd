extends SceneTree
var game: Node3D
var failures := 0
var checks := 0
var skipped := 0
func check(value: bool, description: String) -> void:
	checks+=1
	if value: print("PASS: "+description)
	else: failures+=1; push_error("FAIL: "+description)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames(3)
	check(game.menu.root.visible and not game.match_state.active,"launch into main menu")
	game.menu.show_factions()
	check(game.menu.content.get_child(2) is Button,"faction selection buttons available")
	game.menu.content.get_child(3).pressed.emit()
	check(game.menu.faction==1,"Ronin selection updates deployment")
	game.start_match(0)
	await frames(4)
	check(game.actors.size()==8 and game.player.team==0,"Samurai match starts 4 versus 4")
	check(game.player.camera.current and game.match_state.active,"first person camera and match active")
	for actor in game.actors:
		if actor!=game.player: actor.set_physics_process(false); actor.global_position=Vector3(17,0,17)
	var player: PlayerController=game.player
	player.global_position=Vector3(0,0.05,8)
	player.rotation=Vector3.ZERO
	await frames(5)
	var before := player.position
	Input.action_press("forward")
	await frames(40)
	Input.action_release("forward")
	if DisplayServer.get_name()=="headless":
		skipped+=1; print("SKIP: mouse-captured movement requires a display")
	else: check(player.position.z<before.z-2,"W moves player with physics collision")
	var mouse := InputEventMouseMotion.new(); mouse.relative=Vector2(100,20)
	player._unhandled_input(mouse)
	if DisplayServer.get_name()=="headless":
		skipped+=1; print("SKIP: captured mouse look requires a display")
	else: check(absf(player.rotation.y)>0.1 and absf(player.camera.rotation.x)>0.01,"mouse look yaw and pitch")
	player.rotation=Vector3.ZERO; player.camera.rotation=Vector3.ZERO
	Input.action_press("jump"); await frames(2); Input.action_release("jump")
	check(player.velocity.y>0,"jump uses upward velocity")
	await frames(80)
	check(player.is_on_floor(),"gravity returns player to ground")
	var enemy: BotController=game.actors[4]
	enemy.global_position=Vector3(0,0.05,-2)
	player.global_position=Vector3(0,0.05,3)
	await frames(4)
	var aim := (enemy.global_position+Vector3(0,1.3,0)-player.camera.global_position).normalized()
	if DisplayServer.get_name()!= "headless":
		player.camera.look_at(player.camera.global_position+aim)
		var click := InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(640,360)
		Input.parse_input_event(click)
		await frames(3)
		check(not player.weapons.musket.loaded,"mouse click passes through HUD and fires musket")
	else:
		check(player.weapons.attack(player.camera.global_position,aim),"musket shot accepted")
	check(enemy.health.value==0 and game.match_state.scores[0]==1,"hitscan kills opposing bot and awards team score")
	check(not player.weapons.attack(player.camera.global_position,aim),"second shot blocked and reload starts")
	check(player.weapons.musket.remaining>9,"ten-second reload begins")
	await frames(300)
	check(not player.weapons.musket.loaded and player.weapons.musket.remaining>4,"not loaded after five seconds")
	await frames(310)
	check(player.weapons.musket.loaded and player.weapons.musket.reserve==17,"reload completes and consumes one reserve")
	enemy.respawn(); enemy.global_position=Vector3(0,0.05,1)
	player.weapons.switch_weapon()
	await frames(3)
	aim=(enemy.global_position+Vector3(0,1.3,0)-player.camera.global_position).normalized()
	check(player.weapons.attack(player.camera.global_position,aim) and enemy.health.value==45,"katana damages enemy at close range")
	check(not player.weapons.attack(player.camera.global_position,aim),"katana cooldown blocks repeated same-frame attack")
	await frames(50)
	player.weapons.attack(player.camera.global_position,aim)
	check(enemy.health.value==0,"second katana cut kills")
	var ally: BotController=game.actors[1]
	check(not DamageSystem.hit(ally,100,player) and ally.health.value==100,"allies protected from friendly damage")
	enemy.respawn()
	DamageSystem.hit(player,100,enemy)
	check(player.health.value==0 and game.match_state.scores[1]==1,"enemy kill scores for Ronin and kills player")
	await frames(190)
	check(player.health.value==100 and player.weapons.visible,"player respawns after three seconds with equipment")
	game.set_paused(true)
	var time_before: float=game.match_state.time_left
	await frames(60)
	check(is_equal_approx(game.match_state.time_left,time_before),"pause freezes match clock")
	game.set_paused(false)
	check(game.arena.route(Vector3(-14,0,14),Vector3(14,0,-14)).size()>20,"arena navigation finds route across courtyard")
	game.match_state.score_limit=game.match_state.scores[0]+1
	game.match_state.kill(0)
	check(not game.match_state.active and game.menu.root.visible,"score limit shows match results")
	game.start_match(1,true)
	await frames(3)
	check(game.player.team==1 and game.match_state.scores==[0,0] and game.actors.size()==8,"restart resets scores and supports opposite faction")
	game.match_state.time_left=0.01
	await frames(3)
	check(not game.match_state.active,"timer can end match")
	game.return_menu()
	check(game.menu.root.visible and game.menu_camera.current,"return to main menu restores overview camera")
	# Unscripted combat simulation: no forced damage or target positions.
	game.start_match(0)
	game.match_state.score_limit=1000
	game.player.set_physics_process(false)
	game.player.global_position=Vector3(18,0.1,18)
	var starting_positions: Array[Vector3]=[]
	for actor in game.actors: starting_positions.append(actor.global_position)
	await frames(5400)
	var moved := 0
	for i in range(1,game.actors.size()):
		if game.actors[i].global_position.distance_to(starting_positions[i])>2: moved+=1
	check(moved>=5,"bots autonomously traverse arena")
	check(game.match_state.scores[0]>0 and game.match_state.scores[1]>0,"both bot teams independently score kills over 90 seconds")
	print("BOT SCORES: ",game.match_state.scores)
	print("RESULT: %d checks, %d failures, %d skipped" % [checks,failures,skipped])
	game.free()
	OS.delay_msec(100)
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
