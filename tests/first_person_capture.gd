extends SceneTree
var game: Node3D
func _initialize(): call_deferred("run")
func frames(n: int):
 for i in range(n): await process_frame
func shot(label: String):
 await frames(3)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/fp-"+label+".png")
func run():
 game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 await frames(2); game.start_match(0)
 game.hud.set_process(false); game.hud.root.hide()
 for actor in game.actors: actor.set_physics_process(false)
 game.player.position=Vector3(0,0.05,26); game.player.rotation=Vector3.ZERO
 game.player.camera.rotation=Vector3.ZERO
 var w: WeaponController=game.player.weapons
 var vm: FirstPersonViewmodel=w.viewmodel
 for i in range(60): vm.update(1.0/60)
 await shot("rest")
 Input.action_press("aim")
 for i in range(90): vm.update(1.0/60)
 game.player.camera.fov=55
 await shot("ads")
 print("SIGHTS ",vm.view_camera.unproject_position(w.gun_model.transform*vm.REAR_SIGHT)," ",vm.view_camera.unproject_position(w.gun_model.transform*vm.FRONT_SIGHT)," GRIP ERROR ",vm.palm_error)
 w.recoil=1; vm.update(1.0/60)
 await shot("fire")
 Input.action_release("aim"); w.recoil=0; w.musket.loaded=false; w.musket.remaining=3.3
 for i in range(60): vm.update(1.0/60)
 game.player.camera.fov=78
 await shot("reload-pouch")
 w.musket.remaining=2.45
 for i in range(60): vm.update(1.0/60)
 await shot("reload-load")
 w.musket.remaining=0; w.selected=1; w.shown_weapon=1; w.gun_model.visible=false; w.sword_model.visible=true
 for i in range(60): vm.update(1.0/60)
 await shot("katana")
 w.animation=0.4
 for i in range(60): vm.update(1.0/60)
 await shot("slash")
 w.animation=0; w.switch_time=0.2
 for i in range(60): vm.update(1.0/60)
 await shot("switch")
 game.free(); await frames(2); quit()
