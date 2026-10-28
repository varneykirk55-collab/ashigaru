extends Node3D
var arena: Arena
var match_state: MatchManager
var spawns := SpawnManager.new()
var actors: Array[CharacterBody3D] = []
var player: PlayerController
var hud: HUD
var menu: MainMenu
var sounds: SoundBank
var menu_camera: Camera3D
var paused := false
var sensitivity := 0.002
var player_kills := 0
var player_deaths := 0
var ambient: AudioStreamPlayer
func _ready() -> void:
	seed(7419)
	_inputs()
	_environment()
	arena=Arena.new(); add_child(arena)
	sounds=SoundBank.new(); add_child(sounds)
	load_settings()
	match_state=MatchManager.new(); add_child(match_state)
	match_state.ended.connect(func(): Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; menu.show_results())
	hud=HUD.new(); add_child(hud); hud.setup(self)
	menu=MainMenu.new(); add_child(menu); menu.setup(self)
	ambient=AudioStreamPlayer.new(); add_child(ambient)
	ambient.stream=load("res://assets/audio/ambient.wav"); ambient.volume_db=linear_to_db(maxf(0.001,sounds.volume))-20
	ambient.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD; ambient.play()
	if "--capture" in OS.get_cmdline_user_args(): _capture()
	if "--smoke-match" in OS.get_cmdline_user_args(): _smoke_match()
func _inputs() -> void:
	var bindings := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"sprint":KEY_SHIFT,"reload":KEY_R,"switch":KEY_Q,"pause":KEY_ESCAPE,"crouch":KEY_CTRL}
	for action in bindings:
		InputMap.add_action(action)
		var e := InputEventKey.new(); e.physical_keycode=bindings[action]; InputMap.action_add_event(action,e)
	for pair in [["fire",MOUSE_BUTTON_LEFT],["aim",MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(pair[0]); var e := InputEventMouseButton.new(); e.button_index=pair[1]; InputMap.action_add_event(pair[0],e)
	for wheel in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var e := InputEventMouseButton.new(); e.button_index=wheel; InputMap.action_add_event("switch",e)
func _environment() -> void:
	var environment := WorldEnvironment.new(); add_child(environment)
	var e := Environment.new(); environment.environment=e
	e.background_mode=Environment.BG_SKY
	var sky := Sky.new(); var material := ProceduralSkyMaterial.new()
	material.sky_top_color=Color("435d6a"); material.sky_horizon_color=Color("c4b8a0")
	material.ground_horizon_color=Color("9a9683"); material.ground_bottom_color=Color("474a46")
	sky.sky_material=material; e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("b4c2c9"); e.ambient_light_energy=0.42
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.fog_enabled=true; e.fog_light_color=Color("909b93"); e.fog_density=0.003
	var sun := DirectionalLight3D.new(); add_child(sun)
	sun.rotation_degrees=Vector3(-38,-35,0); sun.light_color=Color("ffdfaa"); sun.light_energy=0.95; sun.shadow_enabled=true
	menu_camera=Camera3D.new(); add_child(menu_camera)
	menu_camera.position=Vector3(17,11,19); menu_camera.look_at(Vector3(0,1,0)); menu_camera.current=true
func start_match(team: int, quick := false) -> void:
	for actor in actors:
		remove_child(actor); actor.queue_free()
	actors.clear(); spawns=SpawnManager.new()
	paused=false; player_kills=0; player_deaths=0
	match_state.scores=[0,0]; match_state.time_left=90 if quick else 240
	match_state.score_limit=5 if quick else 20; match_state.active=true
	player=preload("res://scenes/player.tscn").instantiate(); add_child(player); player.setup(self,team)
	player.sensitivity=sensitivity; actors.append(player); player.respawn()
	for faction in range(2):
		for i in range(3 if faction==team else 4):
			var bot: BotController=preload("res://scenes/bot.tscn").instantiate(); add_child(bot); bot.setup(self,faction); actors.append(bot); bot.respawn()
	menu.root.hide()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _process(delta: float) -> void:
	if not paused: match_state.tick(delta)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and match_state.active:
		set_paused(not paused)
		if paused: menu.show_pause()
		else: menu.root.hide()
func set_paused(value: bool) -> void:
	paused=value
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
func return_menu() -> void:
	match_state.active=false; paused=false
	menu_camera.current=true
	menu.show_main()
func record_kill(attacker: Node, victim: Node) -> void:
	if victim==player: player_deaths+=1
	if is_instance_valid(attacker) and attacker!=victim and attacker.team!=victim.team:
		if attacker==player: player_kills+=1
		match_state.kill(attacker.team)
		hud.message(("SAMURAI" if attacker.team==0 else "RŌNIN")+"  eliminated  "+("SAMURAI" if victim.team==0 else "RŌNIN"))
func feedback(actor: Node, _message: String, _hit: bool) -> void:
	if actor==player:
		hud.confirm(_message)
		sounds.play_sound("hit")
func muzzle(pos: Vector3) -> void:
	var light := OmniLight3D.new(); add_child(light); light.global_position=pos
	light.light_color=Color("ffb45c"); light.light_energy=4; light.omni_range=5
	var tween := create_tween(); tween.tween_property(light,"light_energy",0.0,0.09); tween.tween_callback(light.queue_free)
	for i in range(7):
		var gradient := Gradient.new()
		gradient.set_color(0,Color(0.6,0.59,0.55,0.3))
		gradient.set_color(1,Color(0.6,0.59,0.55,0))
		var texture := GradientTexture2D.new()
		texture.gradient=gradient; texture.width=64; texture.height=64
		texture.fill=GradientTexture2D.FILL_RADIAL
		texture.fill_from=Vector2(0.5,0.5); texture.fill_to=Vector2(1,0.5)
		var m := StandardMaterial3D.new()
		m.albedo_texture=texture; m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var quad := QuadMesh.new(); quad.size=Vector2.ONE
		var smoke := Geometry.mesh(self,quad,pos+Vector3(randf_range(-0.12,0.12),randf_range(-0.1,0.1),randf_range(-0.12,0.12)),m)
		smoke.scale=Vector3.ONE*0.25
		smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var t := create_tween().set_parallel()
		t.tween_property(smoke,"position",smoke.position+Vector3(randf_range(-0.7,0.7),0.8,randf_range(-0.5,0.5)),1.8)
		t.tween_property(smoke,"scale",Vector3.ONE*1.5,1.8)
		t.tween_property(m,"albedo_color:a",0.0,1.8)
		t.chain().tween_callback(smoke.queue_free)
func impact(pos: Vector3) -> void:
	var spark := Geometry.sphere(self,pos,Vector3.ONE*0.07,Geometry.mat(Color("f6bc70")))
	var t := create_tween(); t.tween_interval(0.12); t.tween_callback(spark.queue_free)
func save_settings() -> void:
	var c := ConfigFile.new(); c.set_value("controls","sensitivity",sensitivity); c.set_value("audio","volume",sounds.volume); c.save("user://settings.cfg")
	if is_instance_valid(player): player.sensitivity=sensitivity
	if is_instance_valid(ambient): ambient.volume_db=linear_to_db(maxf(0.001,sounds.volume))-20
func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg")==OK:
		sensitivity=c.get_value("controls","sensitivity",0.002); sounds.volume=c.get_value("audio","volume",0.7)
func _capture() -> void:
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/workspace/ashigaru/docs/menu.png")
	start_match(0)
	player.global_position=Vector3(0,0.1,10)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/workspace/ashigaru/docs/gameplay.png")
	player.weapons.attack(player.camera.global_position,-player.camera.global_basis.z)
	player.weapons.reload()
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/workspace/ashigaru/docs/reload.png")
	player.weapons.switch_weapon()
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/workspace/ashigaru/docs/katana.png")
	get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(ambient): ambient.stop()

func _smoke_match() -> void:
	start_match(0)
	match_state.score_limit=1000
	for i in range(3600): await get_tree().physics_frame
	var ok: bool = match_state.scores[0]>0 and match_state.scores[1]>0
	print("EXPORTED MATCH SMOKE: ","PASS" if ok else "FAIL", " scores=",match_state.scores)
	get_tree().quit(0 if ok else 1)
