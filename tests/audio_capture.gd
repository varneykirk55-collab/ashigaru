extends SceneTree
## Scripted gameplay capture that exercises every audio system with the real game code.
## Run on a display with movie writer so the audio mix is recorded:
##   godot --path . --write-movie dist/audio-demo.avi --fixed-fps 30 --resolution 1280x720 --script tests/audio_capture.gd
var game: Node3D
var caption: Label
func _initialize() -> void:
	call_deferred("run")
func wait(seconds: float) -> void:
	for i in range(int(ceil(seconds*30.0))):
		await process_frame; frame_count+=1
var frame_count := 0
func say(text: String) -> void:
	caption.text=text
	print("CAPTION t=%.1f: %s" % [frame_count/30.0,text])
func face(p: PlayerController, target: Vector3) -> void:
	var d := target-p.camera.global_position
	p.rotation.y=atan2(-d.x,-d.z)
	p.camera.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
func aim_at(p: PlayerController, target: Vector3) -> Vector3:
	face(p,target)
	return (target-p.camera.global_position).normalized()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	var layer := CanvasLayer.new(); layer.layer=100; root.add_child(layer)
	caption=Label.new(); layer.add_child(caption)
	caption.position=Vector2(40,58); caption.size=Vector2(340,220)   # left column: clear of score, prompts and HUD text
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",20)
	caption.add_theme_color_override("font_color",Color("ffe7b0"))
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,1))
	caption.add_theme_constant_override("shadow_offset_x",2); caption.add_theme_constant_override("shadow_offset_y",2)
	var s: SoundBank=game.sounds
	await wait(0.5)
	say("MENU  -  wind, foliage and distant birds (Ambient bus)")
	await wait(4.0)
	game.menu.show_factions()
	var buttons: Array=game.menu.content.find_children("*","Button",true,false)
	say("MENU  -  hover tick, confirm, back")
	buttons[0].mouse_entered.emit(); await wait(0.5)
	buttons[0].pressed.emit(); await wait(0.9)
	buttons=game.menu.content.find_children("*","Button",true,false)
	buttons[buttons.size()-1].mouse_entered.emit(); await wait(0.4)
	buttons[buttons.size()-1].pressed.emit(); await wait(0.9)
	game.start_match(0)
	say("MATCH START  -  taiko and gong stinger")
	var p: PlayerController=game.player
	for actor in game.actors:
		if actor!=p: actor.set_physics_process(false); actor.health.protection=0; actor.global_position=Vector3(60+randf()*8,0.1,60)
	p.health.protection=0
	p.global_position=Vector3(0,0.1,49); p.rotation=Vector3.ZERO
	await wait(3.0)

	# ---- footsteps on three surfaces and in three gaits
	say("FOOTSTEPS  -  stone courtyard, walking (cadence follows speed)")
	Input.action_press("forward"); await wait(4.0)
	say("FOOTSTEPS  -  sprinting is faster and heavier")
	Input.action_press("sprint"); await wait(2.5); Input.action_release("sprint")
	say("FOOTSTEPS  -  crouch walk is slow and soft")
	Input.action_press("crouch"); await wait(2.5); Input.action_release("crouch")
	Input.action_release("forward")
	p.global_position=Vector3(0,0.1,14); p.rotation=Vector3.ZERO
	say("FOOTSTEPS  -  palace wood (hollow), room tone and reverb take over indoors")
	Input.action_press("forward"); await wait(4.0); Input.action_release("forward")
	say("JUMP LANDING  -  wood")
	Input.action_press("jump"); await wait(0.15); Input.action_release("jump"); await wait(1.5)
	p.global_position=Vector3(-60,0.1,6); p.rotation.y=0
	say("FOOTSTEPS  -  garden soil (dull, gritty); foliage and birds outdoors")
	Input.action_press("forward"); await wait(4.0); Input.action_release("forward")

	# ---- musket: fire, staged reload, background reload under the katana
	var bot: BotController=game.actors[5]
	p.global_position=Vector3(0,0.1,6); p.rotation=Vector3.ZERO
	bot.global_position=Vector3(0,0.1,-14)
	await wait(1.0)
	say("MUSKET  -  powerful report with a lock click, blast and courtyard tail")
	var aim := aim_at(p,bot.global_position+Vector3(0,1.4,0))
	p.weapons.attack(p.camera.global_position,aim)
	await wait(1.6)
	say("RELOAD  -  bite, powder, ramrod, tamp, prime and cock, spread over the real 5 s timer")
	await wait(1.4)
	say("EMPTY TRIGGER  -  dry click while reloading")
	p.weapons.attack(p.camera.global_position,aim)
	await wait(1.0)
	say("SWITCH TO KATANA mid reload  -  draw sound; reload finishes quietly in the background")
	p.weapons.switch_weapon()
	await wait(2.2)
	bot.respawn(); bot.health.protection=0; bot.global_position=Vector3(0,0.1,3.5-4.0)
	p.global_position=Vector3(0,0.1,3.5); await wait(0.5)
	say("KATANA  -  a miss: long air whoosh only")
	p.weapons.attack(p.camera.global_position,Vector3(0.6,0.25,-0.75).normalized())
	await wait(1.4)
	say("KATANA  -  a hit: shorter cut, flesh impact, hit tick")
	aim=aim_at(p,bot.global_position+Vector3(0,1.3,0))
	p.weapons.attack(p.camera.global_position,aim)
	await wait(1.4)
	say("KATANA  -  killing cut: kill confirmation, death cry and fall")
	aim=aim_at(p,bot.global_position+Vector3(0,1.3,0))
	p.weapons.attack(p.camera.global_position,aim)
	await wait(3.0)
	say("KATANA  -  blade against scenery rings off the surface")
	p.weapons.attack(p.camera.global_position,Vector3(0,-1,-0.05).normalized())
	await wait(1.6)
	p.weapons.switch_weapon()
	say("SWITCH TO MUSKET  -  raise")
	await wait(2.0)

	# ---- enemy gunfire is positional: left, right, then far away
	bot.respawn(); bot.health.protection=0
	p.global_position=Vector3(0,0.1,30); p.rotation=Vector3.ZERO
	await wait(0.6)
	say("ENEMY MUSKET  -  positional: heard from the left")
	bot.global_position=Vector3(-9,0.1,26)
	bot.weapons.musket=Musket.new()
	bot.weapons.attack(bot.global_position+Vector3(0,1.4,0),Vector3(0.7,-0.05,0.4).normalized())
	await wait(2.2)
	say("ENEMY MUSKET  -  positional: heard from the right")
	bot.global_position=Vector3(9,0.1,26)
	bot.weapons.musket=Musket.new()
	bot.weapons.attack(bot.global_position+Vector3(0,1.4,0),Vector3(-0.7,-0.05,0.4).normalized())
	await wait(2.2)
	say("DISTANCE  -  50 m: duller, delayed, with echo")
	bot.global_position=Vector3(50,0.1,40)
	bot.weapons.musket=Musket.new()
	bot.weapons.attack(bot.global_position+Vector3(0,1.4,0),Vector3(-1,0,0))
	await wait(2.8)
	say("DISTANCE  -  100 m: distant thud and rolling echo")
	bot.global_position=Vector3(66,0.1,-60)
	bot.weapons.musket=Musket.new()
	bot.weapons.attack(bot.global_position+Vector3(0,1.4,0),Vector3(-1,0,0))
	await wait(3.5)
	bot.global_position=Vector3(60,0.1,60); bot.set_physics_process(false)

	# ---- being hit and dying
	say("DAMAGE REACTION  -  hit by an enemy")
	var shooter: BotController=game.actors[6]
	shooter.health.protection=0
	shooter.global_position=Vector3(0,0.1,18)
	p.health.protection=0
	DamageSystem.hit(p,40,shooter)
	await wait(2.0)
	say("DEATH  -  cry, fall, then RESPAWN cue after three seconds")
	DamageSystem.hit(p,100,shooter)
	await wait(5.0)
	shooter.global_position=Vector3(60,0.1,60)

	# ---- open fight: all bots autonomous
	say("FULL 5v5 FIGHT  -  positional gunfire, reloads, footsteps from all directions (palace garden)")
	for actor in game.actors:
		if actor!=p: actor.set_physics_process(true)
	p.set_physics_process(false)
	p.global_position=Vector3(-38,0.1,2); p.rotation.y=-PI/2
	game.match_state.score_limit=1000
	await wait(30.0)
	say("FULL 5v5 FIGHT  -  inside the palace: closed-in ambience and longer reverb")
	p.global_position=Vector3(0,0.1,0)
	await wait(18.0)
	say("MATCH END  -  victory stinger")
	game.match_state.score_limit=maxi(game.match_state.scores[0],game.match_state.scores[1])+1
	game.match_state.kill(0 if game.match_state.scores[0]>=game.match_state.scores[1] else 1)
	await wait(6.0)
	game.free()
	OS.delay_msec(100)
	quit()
