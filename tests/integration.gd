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
	check(game.actors.size()==10 and game.player.team==0,"Samurai match starts 5 versus 5")
	check(game.player.camera.current and game.match_state.active,"first person camera and match active")
	for actor in game.actors:
		if actor!=game.player: actor.set_physics_process(false); actor.health.protection=0; actor.global_position=Vector3(17,0,17)
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
	var enemy: BotController=game.actors[5]
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
	await frames(3)
	check(player.weapons.gun_model.position.z>0.02,"musket recoil animates rearward after firing")
	check(enemy.health.value==0 and game.match_state.scores[0]==1,"hitscan kills opposing bot and awards team score")
	check(not player.weapons.attack(player.camera.global_position,aim),"second shot blocked and reload starts")
	check(player.weapons.musket.remaining>4,"five-second automatic background reload begins")
	await frames(150)
	check(not player.weapons.musket.loaded and player.weapons.musket.remaining>2,"not loaded halfway through five-second reload")
	check(player.weapons.gun_model.rotation.z>0.4,"musket visibly tilts during reload")
	player.weapons.switch_weapon()
	check(player.weapons.gun_model.visible,"weapon switch begins without instantly hiding the old weapon")
	await frames(8)
	check(player.weapons.gun_model.position.y< -0.1,"weapon switch lowers weapon smoothly")
	await frames(152)
	check(player.weapons.sword_model.visible and not player.weapons.gun_model.visible,"weapon switch finishes on the katana")
	check(player.weapons.musket.loaded and player.weapons.musket.reserve==17,"background reload completes while katana equipped and consumes one reserve")
	enemy.respawn(); enemy.health.protection=0; enemy.global_position=Vector3(0,0.05,1)
	await frames(3)
	aim=(enemy.global_position+Vector3(0,1.3,0)-player.camera.global_position).normalized()
	check(player.weapons.attack(player.camera.global_position,aim) and enemy.health.value==45,"katana damages enemy at close range")
	await frames(8)
	check(player.weapons.sword_model.rotation.length()>0.2,"katana swing animates through an arc")
	check(not player.weapons.attack(player.camera.global_position,aim),"katana cooldown blocks repeated same-frame attack")
	await frames(50)
	player.weapons.attack(player.camera.global_position,aim)
	check(enemy.health.value==0,"second katana cut kills")
	var ally: BotController=game.actors[1]
	check(not DamageSystem.hit(ally,100,player) and ally.health.value==100,"allies protected from friendly damage")
	enemy.respawn(); enemy.health.protection=0
	player.health.protection=0
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
	check(game.player.team==1 and game.match_state.scores==[0,0] and game.actors.size()==10,"restart resets scores and supports opposite faction")
	game.match_state.time_left=0.01
	await frames(3)
	check(not game.match_state.active,"timer can end match")
	game.return_menu()
	check(game.menu.root.visible and game.menu_camera.current,"return to main menu restores overview camera")
	# Presentation regressions exercise actual collision and actor lifecycles.
	game.start_match(0)
	await frames(3)
	player=game.player
	for actor in game.actors:
		if actor!=player: actor.set_physics_process(false); actor.health.protection=0; actor.position=Vector3(17,0.1,17)
	player.position=Vector3(0,0.1,3)
	Input.action_press("crouch")
	await frames(30)
	check(player.crouch_blend>0.9 and player.camera.position.y<1.3,"crouch smoothly lowers camera and collider")
	Input.action_release("crouch")
	await frames(35)
	check(player.crouch_blend<0.05 and player.camera.position.y>1.6,"standing blends back from crouch")
	enemy=game.actors[5]; enemy.position=Vector3(0,0.1,-2)
	await frames(3)
	var head_ray := DamageSystem.trace(player,player.camera.global_position,(enemy.global_position+Vector3(0,enemy.head_height(),0)-player.camera.global_position).normalized(),20)
	check(not head_ray.is_empty() and head_ray.collider==enemy and head_ray.get("headshot",false),"physical head hitbox identifies a headshot")
	var chest_ray := DamageSystem.trace(player,player.camera.global_position,(enemy.global_position+Vector3(0,1.0,0)-player.camera.global_position).normalized(),20)
	check(not chest_ray.is_empty() and not chest_ray.get("headshot",false),"body hit is not falsely labeled headshot")
	var rig: CharacterAnimator=enemy.visual
	var leg_min := INF
	var leg_max := -INF
	for step in range(60):
		rig.tick(1.0/60.0,3,false,enemy.weapons)
		leg_min=minf(leg_min,rig.ronin.skeleton.get_bone_global_pose(rig.ronin.skeleton.find_bone("foot_l")).origin.z if is_instance_valid(rig.ronin) else rig.joints.left_leg.rotation.x)
		leg_max=maxf(leg_max,rig.ronin.skeleton.get_bone_global_pose(rig.ronin.skeleton.find_bone("foot_l")).origin.z if is_instance_valid(rig.ronin) else rig.joints.left_leg.rotation.x)
	check(leg_max-leg_min>0.3,"walk articulates legs through a full gait cycle")
	rig.tick(0.2,7,false,enemy.weapons)
	check(rig.motion_state=="sprint","sprint animation state follows movement speed")
	rig.tick(0.3,2,true,enemy.weapons)
	check((rig.motion_state=="crouch_walk" or is_instance_valid(rig.ronin)) and rig.position.y< -0.25,"crouch movement animates lowered rig")
	rig.reset_pose()
	DamageSystem.hit(enemy,10,player)
	rig.tick(0.08,0,false,enemy.weapons)
	check(rig.damage_pulse>0 and (rig.ronin.state=="hit" if is_instance_valid(rig.ronin) else rig.joints.torso.rotation.x>0.01),"taking damage produces visible torso reaction")
	player.weapons.attack(player.camera.global_position,(enemy.global_position+Vector3(0,enemy.head_height(),0)-player.camera.global_position).normalized())
	check("HEADSHOT" in player.weapons.hit_kind and "KILL" in game.hud.confirm_text,"headshot kill has distinct confirmation")
	check(rig.visible and rig.death_time==0 and not rig.death_finished,"dead bot remains visible at start of death")
	check(not enemy.weapons.attack(enemy.global_position+Vector3.UP,Vector3.FORWARD),"dead bot cannot attack")
	enemy.set_physics_process(true)
	var death_position: Vector3=enemy.global_position
	await frames(166)
	check(rig.death_finished and rig.visible and (rig.ronin.skeleton.get_bone_global_pose(rig.ronin.head_bone).origin.y<1.0 if is_instance_valid(rig.ronin) else rig.rotation.x>1.4),"death finishes with visible fallen body before cleanup")
	check(enemy.global_position.distance_to(death_position)<0.01,"dead actor stops locomotion")
	await frames(24)
	check(enemy.health.value==100 and rig.death_time<0 and rig.visible,"body is recycled only after death delay and combatant respawns")
	rig.tick(0.3,0,true,enemy.weapons)
	var crouch_death_y: float=rig.position.y
	rig.die(); rig.tick(1.0/60,0,false,enemy.weapons)
	check(absf(rig.position.y-crouch_death_y)<0.01,"crouched death starts without a vertical pose pop")
	rig.reset_pose()
	check(is_equal_approx(player.weapons.musket.RELOAD_TIME,5.0),"reload contract remains five seconds")
	# Unscripted combat simulation: no forced damage or target positions.
	game.start_match(0)
	game.match_state.score_limit=1000
	game.player.set_physics_process(false)
	game.player.global_position=Vector3(18,0.1,18)
	var starting_positions: Array[Vector3]=[]
	for actor in game.actors: starting_positions.append(actor.global_position)
	await frames(10800)
	var moved := 0
	for i in range(1,game.actors.size()):
		if game.actors[i].global_position.distance_to(starting_positions[i])>2: moved+=1
	check(moved>=5,"bots autonomously traverse arena")
	check(game.match_state.scores[0]>0 and game.match_state.scores[1]>0,"both bot teams independently score kills over 180 seconds")
	print("BOT SCORES: ",game.match_state.scores)
	game.match_state.score_limit=maxi(game.match_state.scores[0],game.match_state.scores[1])+1
	await frames(3600)
	check(not game.match_state.active and game.menu.root.visible,"autonomous combat reaches score-limit results without forced kills")
	print("RESULT: %d checks, %d failures, %d skipped" % [checks,failures,skipped])
	game.free()
	OS.delay_msec(100)
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
