extends SceneTree
var failures := 0
var checks := 0
var game: Node3D
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
 checks+=1
 if value: print("PASS: "+message)
 else: failures+=1; push_error("FAIL: "+message)
func frames(count: int):
 for i in range(count): await physics_frame
func mouse(button: int, pressed: bool):
 var event := InputEventMouseButton.new(); event.button_index=button; event.pressed=pressed; event.position=Vector2(640,360); Input.parse_input_event(event)
func run():
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 await frames(3); game.start_match(0); await frames(4)
 var p: PlayerController=game.player
 var w: WeaponController=p.weapons
 var vm: FirstPersonViewmodel=w.viewmodel
 for actor in game.actors:
  if actor!=p: actor.set_physics_process(false); actor.health.protection=0; actor.position=Vector3(50,0.1,50)
 p.position=Vector3(0,0.1,26); p.rotation=Vector3.ZERO; p.camera.rotation=Vector3.ZERO
 await frames(30)
 check(vm.skeleton.get_bone_count()==58 and vm.rig.find_children("*","MeshInstance3D",true,false).size()==2,"first-person arms use original 58-bone skin and two source body/sleeve meshes")
 var triangles := 0
 for part: MeshInstance3D in vm.rig.find_children("*","MeshInstance3D",true,false):
  check(part.mesh is ArrayMesh and part.skin.get_bind_count()==58,"arm mesh retains original skin binds and material surfaces")
  for surface in range(part.mesh.get_surface_count()): triangles+=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
 check(triangles>2000,"modeled arm/hand geometry replaces primitive spheres and cylinders")
 print("ARM TRIANGLES: ",triangles)
 check(vm.palm_error<0.025,"both musket palms converge onto weapon grips")
 check(vm.viewport.own_world_3d and vm.viewport.transparent_bg and vm.image.mouse_filter==Control.MOUSE_FILTER_IGNORE,"isolated transparent viewmodel avoids wall clipping and does not intercept input")
 check(w.gun_model.get_child_count()==2 and w.gun_model.get_child(1)==vm.flash,"musket has only its original model and muzzle flash, with no added sight assembly")
 mouse(MOUSE_BUTTON_RIGHT,true); await frames(5)
 check(vm.ads>0.1 and vm.ads<0.9 and w.gun_model.position.x>0.01 and w.gun_model.position.x<0.13,"ADS physically raises/centers the gun through intermediate poses")
 await frames(45)
 check(vm.ads>0.99 and p.camera.fov<56,"real right mouse input raises musket into ADS")
 var center := Vector2(vm.viewport.size)*0.5
 var rear := vm.view_camera.unproject_position(w.gun_model.transform*vm.AIM_REAR)
 var front := vm.view_camera.unproject_position(w.gun_model.transform*vm.AIM_FRONT)
 check(rear.distance_to(center)<0.5 and front.distance_to(center)<0.5,"original low-profile barrel aiming references project to screen center")
 check(game.hud.hit.modulate.a<0.01,"hip reticle fades away during settled ADS")
 Input.action_press("forward"); await frames(20); Input.action_release("forward")
 var drift := vm.view_camera.unproject_position(w.gun_model.transform*vm.AIM_FRONT).distance_to(center)
 check(p.velocity.length()>0 and drift<1.5,"movement works during ADS with less than 1.5 pixels of sight drift")
 p.position=Vector3(0,0.1,26); await frames(5)
 var enemy: BotController=game.actors[5]; enemy.position=Vector3(0,0.1,20); enemy.health.protection=0
 await frames(4)
 mouse(MOUSE_BUTTON_LEFT,true); await frames(1); mouse(MOUSE_BUTTON_LEFT,false)
 check(enemy.health.value==0 and game.match_state.scores[0]==1,"ADS camera ray hits the enemy along the original barrel and scores the kill")
 check(w.recoil>0.8 and vm.flash.visible,"firing produces weapon recoil and a brief muzzle flash")
 check(w.musket.remaining>4.9 and not w.musket.loaded,"successful firing starts the original five-second automatic reload")
 mouse(MOUSE_BUTTON_RIGHT,false)
 await frames(100)
 check(vm.reload_stage=="pouch" and vm.left_target.y< -0.45,"reload support hand leaves the gun and reaches toward the pouch")
 var remaining := w.musket.remaining
 w.switch_weapon(); await frames(24)
 check(w.selected==1 and w.shown_weapon==1 and not w.gun_model.visible and w.sword_model.visible,"switch finishes on katana with musket animation hidden")
 check(w.musket.remaining<remaining-0.3 and w.musket.remaining>remaining-0.5,"switching continues the same ammunition clock")
 enemy.respawn(); enemy.health.protection=0; enemy.position=Vector3(0,0.1,24)
 await frames(3)
 check(w.attack(p.camera.global_position,-p.camera.global_basis.z) and enemy.health.value==45,"katana remains usable for unchanged 55 damage during background reload")
 var sword_pose := w.sword_model.transform
 await frames(10)
 check(w.sword_model.rotation.length()>0.4 and w.sword_model.position.distance_to(sword_pose.origin)>0.08,"katana swing visibly moves the weapon and articulated wrists")
 check(vm.palm_error<0.06,"both katana palms follow the moving hilt")
 w.switch_weapon(); var resume := w.musket.remaining; await frames(24)
 check(w.shown_weapon==0 and w.musket.remaining<resume and w.musket.remaining>resume-0.5,"returning to musket restores remaining reload state without restarting it")
 check(vm.reload_stage in ["load","mechanism","return"],"resumed reload samples its current loading/handling stage")
 while w.musket.remaining>0: await frames(1)
 check(w.musket.loaded and w.musket.reserve==17,"five-second timer completes with exactly one reserve consumed")
 await frames(40)
 check(vm.reload_stage=="ready" and vm.palm_error<0.025,"reload finishes with both hands back on the weapon")
 check(Musket.RELOAD_TIME==5.0 and Katana.DAMAGE==55.0 and Katana.COOLDOWN==0.8,"reload and katana gameplay constants remain unchanged")
 # A wall between the eye and target must still occlude the hit, even though the
 # separate weapon presentation is never cut by nearby world geometry.
 enemy.respawn(); enemy.health.protection=0; enemy.position=Vector3(0,0.1,20)
 var wall := StaticBody3D.new(); game.add_child(wall); wall.position=p.camera.global_position+Vector3(0,0,-0.4)
 var collision := CollisionShape3D.new(); wall.add_child(collision); var box := BoxShape3D.new(); box.size=Vector3(1,1,0.1); collision.shape=box
 await frames(3)
 check(w.attack(p.camera.global_position,Vector3.FORWARD) and enemy.health.value==100,"hip-fire works and eye-line wall occlusion prevents shooting through nearby cover")
 wall.queue_free()
 var elapsed := 0.0
 while w.musket.remaining>0:
  await frames(1); elapsed+=1.0/60
 check(elapsed>4.9 and elapsed<5.1,"production physics reload duration measures five seconds")
 Input.action_press("crouch"); mouse(MOUSE_BUTTON_RIGHT,true); await frames(45)
 check(p.crouch_blend>0.99 and vm.ads>0.99 and vm.palm_error<0.025,"crouching retains the camera-relative ADS grip")
 Input.action_release("crouch"); mouse(MOUSE_BUTTON_RIGHT,false); Input.action_press("forward"); Input.action_press("sprint")
 await frames(20)
 check(Vector2(p.velocity.x,p.velocity.z).length()>6.9,"sprint movement remains functional")
 Input.action_release("forward"); Input.action_release("sprint")
 mouse(MOUSE_BUTTON_RIGHT,true); await frames(30)
 p.health.protection=0; DamageSystem.hit(p,100,enemy); await frames(2)
 check(vm.ads==0 and not vm.overlay.visible and not w.attack(p.camera.global_position,Vector3.FORWARD),"death exits ADS, hides the viewmodel and blocks attacks")
 await frames(190)
 check(p.health.value==100 and vm.overlay.visible and w.musket.loaded and w.recoil==0 and w.animation==0,"respawn restores a clean, ready viewmodel after the existing death delay")
 check(vm.ads==0 and vm.aim_blocked,"holding right mouse through death does not restore stale ADS")
 mouse(MOUSE_BUTTON_RIGHT,false); await frames(2); mouse(MOUSE_BUTTON_RIGHT,true); await frames(40)
 check(vm.ads>0.99,"fresh right-click after respawn enters ADS normally")
 mouse(MOUSE_BUTTON_RIGHT,false)
 game.return_menu(); await frames(3)
 check(not vm.overlay.visible,"returning to menu hides the viewmodel overlay")
 print("RESULT: %d checks, %d failures" % [checks,failures])
 game.free(); OS.delay_msec(100); await process_frame; await process_frame; quit(0 if failures==0 else 1)
