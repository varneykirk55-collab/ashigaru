extends SceneTree
var game: Node3D
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks+=1
	if ok: print("PASS: "+text)
	else: failures+=1; push_error("FAIL: "+text)
func clips_equal(a: Animation, b: Animation) -> bool:
	if a.get_track_count()!=b.get_track_count() or not is_equal_approx(a.length,b.length): return false
	for track in range(a.get_track_count()):
		if a.track_get_type(track)!=b.track_get_type(track) or a.track_get_path(track)!=b.track_get_path(track) or a.track_get_key_count(track)!=b.track_get_key_count(track): return false
		for key in range(a.track_get_key_count(track)):
			if a.track_get_key_time(track,key)!=b.track_get_key_time(track,key) or a.track_get_key_value(track,key)!=b.track_get_key_value(track,key): return false
	return true
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames(3); game.start_match(0); await frames(3)
	var bot: BotController=game.actors[5]
	var rig: CharacterAnimator=bot.visual
	var r: RoninPresentation=rig.ronin
	check(is_instance_valid(r) and r.skeleton.get_bone_count()==58,"actual 58-bone rōnin rig is assigned to faction")
	check(not is_instance_valid(game.actors[1].visual.ronin),"Samurai keeps distinguishable armored placeholder")
	var triangles := 0; var meshes := 0; var skinned := 0; var textures := 0; var hair := false
	for part in r.visual.find_children("*","MeshInstance3D",true,false):
		meshes+=1
		if part.skin!=null: skinned+=1
		for surface in range(part.mesh.get_surface_count()):
			var arrays: Array=part.mesh.surface_get_arrays(surface)
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
			var m: StandardMaterial3D=part.get_active_material(surface)
			if m.albedo_texture!=null: textures+=1
			if "Hair" in part.name: hair=m.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and m.albedo_texture!=null
	check(triangles==93590 and meshes==14 and skinned==14,"93,590 triangles and all 14 skinned meshes retained")
	check(textures==16 and hair,"textured surfaces and masked hair survive import")
	check(r.player.get_animation_list().size()==9,"all nine authored clips retained")
	var original: Node3D=preload("res://assets/characters/Ronin.glb").instantiate()
	var original_player: AnimationPlayer=original.find_children("*","AnimationPlayer",true,false)[0]
	for name in ["Idle","Walk","Run","Musket_Aim","Musket_Fire","Musket_Reload","Katana_Slash","Hit_React","Death"]:
		check(r.player.has_animation(name) and clips_equal(r.player.get_animation(name),original_player.get_animation(name)),"imported animation keyframes preserved: "+name)
	original.free()
	for actor in game.actors: actor.set_physics_process(false)
	bot.health.protection=0
	rig.tick(0.1,0,false,bot.weapons,false)
	check(r.state=="idle" and r.player.current_animation=="Idle","supplied idle clip plays when not aiming")
	for i in range(60): rig.tick(1.0/60,0,false,bot.weapons)
	check((-rig.weapon_socket.basis.z).dot(Vector3.FORWARD)>0.99,"musket aim axis matches combatant forward direction")
	rig.react(); rig.tick(0.15,0,false,bot.weapons)
	var hit_clip := r.player.get_animation("Hit_React")
	var reference := Quaternion.IDENTITY
	for track in range(hit_clip.get_track_count()):
		if hit_clip.track_get_type(track)==Animation.TYPE_ROTATION_3D and str(hit_clip.track_get_path(track)).ends_with(":spine_01"):
			reference=hit_clip.rotation_track_interpolate(track,r.player.current_animation_position)
	check(r.skeleton.get_bone_pose_rotation(r.skeleton.find_bone("spine_01")).angle_to(reference)<0.5,"musket hit reaction retains authored torso pose instead of forcing aim twist")
	var foot := r.skeleton.find_bone("foot_l")
	rig.reset_pose(); rig.tick(0.1,2,false,bot.weapons)
	var start: Vector3=r.skeleton.get_bone_global_pose(foot).origin
	for i in range(20): bot.weapons.tick(1.0/60); rig.tick(1.0/60,2,false,bot.weapons)
	check(r.state=="walk" and start.distance_to(r.skeleton.get_bone_global_pose(foot).origin)>0.05,"walk clip deforms the skeleton over time")
	rig.tick(0.1,6,false,bot.weapons)
	check(r.state=="sprint" and r.player.current_animation=="Run","run clip drives sprint presentation")
	for i in range(60): rig.tick(1.0/60,0,true,bot.weapons)
	var foot_world: Vector3=rig.transform*(r.visual.transform*r.skeleton.get_bone_global_pose(foot).origin)
	print("CROUCH FOOT Y ",foot_world.y," BODY OFFSET ",rig.position.y)
	check(rig.position.y< -0.25 and foot_world.y> -0.04 and foot_world.y<0.2,"compatible crouch lowers body while keeping feet grounded")
	rig.reset_pose(); bot.weapons.musket=Musket.new(); bot.weapons.musket.loaded=false; bot.weapons.reload()
	for i in range(150): bot.weapons.tick(1.0/60); rig.tick(1.0/60,0,false,bot.weapons)
	check(r.state=="reload" and absf(r.player.current_animation_position-r.player.get_animation("Musket_Reload").length*0.5)<0.15,"11.13-second source reload retimed to five-second mechanic")
	var moving_foot: Vector3=r.skeleton.get_bone_global_pose(foot).origin
	for i in range(30): bot.weapons.tick(1.0/60); rig.tick(1.0/60,3.2,false,bot.weapons)
	check(r.state=="reload" and moving_foot.distance_to(r.skeleton.get_bone_global_pose(foot).origin)>0.05,"lower-body locomotion continues during moving reload")
	bot.weapons.switch_weapon()
	for i in range(160): bot.weapons.tick(1.0/60); rig.tick(1.0/60,0,false,bot.weapons)
	check(bot.weapons.musket.loaded and bot.weapons.selected==1,"background reload still finishes with katana equipped")
	bot.weapons.animation=0.65; rig.tick(1.0/60,0,false,bot.weapons)
	check(r.state=="katana_attack" and r.player.current_animation=="Katana_Slash","katana attack uses supplied clip")
	for i in range(55): bot.weapons.tick(1.0/60); rig.tick(1.0/60,0,false,bot.weapons)
	bot.weapons.attack(bot.global_position+Vector3.UP,Vector3.FORWARD)
	rig.tick(1.0/60,0,false,bot.weapons)
	check(r.state=="katana_attack" and r.player.current_animation_position<0.1,"repeated katana attacks restart the supplied slash clip")
	rig.react(); rig.tick(1.0/60,0,false,bot.weapons)
	check(r.state=="hit" and r.player.current_animation=="Hit_React","damage reaction uses supplied clip")
	rig.die()
	for i in range(100): rig.tick(1.0/60,0,false,bot.weapons)
	check(not rig.death_finished and rig.visible,"body retained during authored death")
	for i in range(70): rig.tick(1.0/60,0,false,bot.weapons)
	check(rig.death_finished and r.skeleton.get_bone_global_pose(r.head_bone).origin.y<0.8,"death clip completes with fallen body")
	rig.reset_pose()
	for i in range(60): rig.tick(1.0/60,0,true,bot.weapons)
	rig.die()
	for i in range(170): rig.tick(1.0/60,0,false,bot.weapons)
	check(rig.death_finished and absf(rig.position.y)<0.01,"crouched death blends back to authored ground plane without sinking")
	bot.weapons.recoil=1; bot.weapons.animation=0.4; bot.respawn(); rig.tick(1.0/60,0,false,bot.weapons)
	check(bot.weapons.recoil==0 and bot.weapons.animation==0 and r.state not in ["fire","katana_attack"],"respawn clears stale firing/slash presentation without a phantom attack")
	game.start_match(1)
	await frames(4)
	var p: PlayerController=game.player
	check(is_instance_valid(p.visual.ronin) and p.camera.current,"rōnin player has external rig and retains first-person camera")
	var own_hidden := true
	for part in p.visual.find_children("*","VisualInstance3D",true,false): own_hidden=own_hidden and (part.layers & p.camera.cull_mask)==0
	check(own_hidden,"own full body and external weapons cannot obscure first-person camera")
	check(p.weapons.gun_model.visible and (p.weapons.gun_model.find_children("*","VisualInstance3D",true,false)[0].layers & p.camera.cull_mask)!=0,"existing first-person weapon remains visible")
	game.match_state.score_limit=10; game.match_state.time_left=360
	await frames(18000)
	check(game.actors.size()==10 and not game.match_state.active and game.match_state.scores[0]>0 and game.match_state.scores[1]>0,"full mixed-faction 5v5 match completes with both teams scoring")
	print("RONIN MATCH ",game.match_state.scores)
	print("RONIN RESULT: %d checks, %d failures" % [checks,failures])
	game.free(); OS.delay_msec(100); quit(0 if failures==0 else 1)
