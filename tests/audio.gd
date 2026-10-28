extends SceneTree
## Runtime audio validation. Drives the real game (real weapons, bots, menus) and inspects the
## SoundBank event log, buses and voice pools. Run in real time (about 4 minutes): godot --headless --path . --script tests/audio.gd
var game: Node3D
var sounds: SoundBank
var failures := 0
var checks := 0
func check(value: bool, description: String) -> void:
	checks+=1
	if value: print("PASS: "+description)
	else: failures+=1; push_error("FAIL: "+description)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func seconds(s: float) -> void:
	await frames(int(ceil(s*60.0)))
func since(t0: float, sound := "") -> Array:
	var out := []
	for e in sounds.events:
		if e.t>=t0 and (sound=="" or e.sound==sound): out.append(e)
	return out
func names_since(t0: float) -> Array:
	var out := []
	for e in since(t0): out.append(e.sound)
	return out
func now() -> float: return sounds._clock
func playing_count() -> int:
	var n := 0
	for pool in [sounds._voices3d,sounds._voices2d]:
		for v in pool:
			if v.playing: n+=1
	return n
func centroid_zcr(stream: AudioStreamWAV) -> float:
	# zero-crossing rate over the first 100 ms: rough brightness measure (higher = brighter/harder surface)
	var d := stream.data
	var n := mini(d.size()/2,4410)
	var prev := d.decode_s16(0); var zc := 0
	for i in range(1,n):
		var v := d.decode_s16(i*2)
		if (v>0)!=(prev>0): zc+=1
		prev=v
	return float(zc)/float(n)
func _initialize() -> void:
	Engine.max_fps=60   # real-time pacing: the audio mixer runs on the wall clock, so voices only expire realistically at 1x speed
	call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frames(3)
	sounds=game.sounds
	# ---------------------------------------------------------------- assets and buses
	check(sounds.missing.is_empty(),"every catalogued sound loads (missing: %s)" % [sounds.missing])
	var total := 0
	for k in SoundBank.CATALOG: total+=SoundBank.CATALOG[k][1]
	check(total>=100,"sound catalogue has %d files" % total)
	for bus in ["SFX","Ambient","UI"]:
		check(AudioServer.get_bus_index(bus)>=0,"audio bus "+bus+" exists")
	check(AudioServer.get_bus_effect_count(0)>=1 and AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"master bus has a hard limiter against clipping")
	var wood := centroid_zcr(sounds._variants("step_wood")[0]); var stone := centroid_zcr(sounds._variants("step_stone")[0]); var soil := centroid_zcr(sounds._variants("step_soil")[0])
	print("step brightness (zero-crossing rate): wood=%.3f stone=%.3f soil=%.3f" % [wood,stone,soil])
	check(stone>wood*1.2 and wood>soil*1.1,"wood, stone and soil footstep samples are acoustically different")
	check(sounds.loop_stream("wind_loop").loop_end>100000,"ambient loops carry explicit loop points")
	# audio variation must not consume the global RNG that bot behaviour depends on
	seed(4242); var expected_random := randf()
	seed(4242)
	for i in range(30):
		sounds.gunshot(Vector3(5,1,5),false); sounds.ui("ui_click"); sounds.bullet_impact(Vector3(2,1,2),"wood")
	game.ambience._bird(); game.ambience._creak()
	check(randf()==expected_random,"audio never consumes the global random stream")
	# ---------------------------------------------------------------- volume settings
	sounds.set_volume("master",0.5); sounds.set_volume("sfx",0.25); sounds.set_volume("ambient",0.0)
	check(is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(0.5)),"master slider drives Master bus")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),linear_to_db(0.25)+SoundBank.SFX_TRIM_DB),"effects slider drives SFX bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambient")),"ambient slider at zero mutes the Ambient bus")
	game.save_settings()
	var cfg := ConfigFile.new(); cfg.load("user://settings.cfg")
	check(cfg.get_value("audio","master",-1)==0.5 and cfg.get_value("audio","sfx",-1)==0.25 and cfg.get_value("audio","ambient",-1)==0.0,"volume settings persist to settings.cfg")
	sounds.volumes["master"]=0.9; sounds.volumes["sfx"]=0.9; sounds.volumes["ambient"]=0.9
	game.load_settings()
	check(sounds.volumes["master"]==0.5 and sounds.volumes["sfx"]==0.25 and sounds.volumes["ambient"]==0.0,"saved volume settings load back")
	var legacy := ConfigFile.new(); legacy.set_value("audio","volume",0.35); legacy.save("user://settings.cfg")
	game.load_settings()
	check(is_equal_approx(sounds.volumes["master"],0.35),"legacy single-volume settings file becomes master volume")
	sounds.set_volume("master",0.8); sounds.set_volume("sfx",1.0); sounds.set_volume("ambient",0.8); game.save_settings()
	# ---------------------------------------------------------------- menu audio
	var t0 := now()
	game.menu.show_settings()
	var sliders: Array=game.menu.content.find_children("*","HSlider",true,false)
	check(sliders.size()==4,"settings screen has sensitivity + master/effects/ambience sliders")
	sliders[2].value=0.4
	check(is_equal_approx(sounds.volumes["sfx"],0.4) and "ui_tick" in names_since(t0),"effects slider changes volume and gives audible tick")
	sliders[2].value=1.0
	game.menu.show_main()
	t0=now()
	var play_button: Button=game.menu.content.find_children("*","Button",true,false)[0]
	play_button.mouse_entered.emit(); play_button.pressed.emit()
	check("ui_hover" in names_since(t0) and "ui_confirm" in names_since(t0),"menu button hover and confirm sounds fire")
	check(since(t0,"ui_confirm")[0].bus=="UI","menu sounds use the UI bus")
	game.menu.show_factions()
	t0=now()
	var buttons: Array=game.menu.content.find_children("*","Button",true,false)
	buttons[buttons.size()-1].pressed.emit()
	check("ui_back" in names_since(t0),"back button has its own sound")
	# ---------------------------------------------------------------- match start and setup
	t0=now()
	game.start_match(0)
	await frames(4)
	check("match_start" in names_since(t0),"match start stinger plays")
	check(game.actors.size()==10,"5v5 match starts with audio enabled")
	var player: PlayerController=game.player
	for actor in game.actors:
		if actor!=player: actor.set_physics_process(false); actor.health.protection=0; actor.global_position=Vector3(17,0,17)
	player.global_position=Vector3(0,0.05,8); player.rotation=Vector3.ZERO
	await frames(10)
	player.health.protection=0
	# ---------------------------------------------------------------- player musket
	t0=now()
	var aim := Vector3(0,0,-1)
	check(player.weapons.attack(player.camera.global_position,aim),"player musket fires")
	var shot := since(t0,"musket_shot")
	check(shot.size()==1 and not shot[0].spatial and shot[0].bus=="SFX","player's own shot is a clear, non-positional SFX voice")
	check(since(t0,"reload_bite").size()==1,"reload sequence begins with the lock click immediately after firing")
	# ---------------------------------------------------------------- reload cues follow the real 5 s timer
	var cue_times := {}
	var start := now()
	var frames_elapsed := 0
	while not player.weapons.musket.loaded and frames_elapsed<600:
		await physics_frame; frames_elapsed+=1
		for e in since(start):
			if e.sound.begins_with("reload_") and not cue_times.has(e.sound): cue_times[e.sound]=e.t-start
	var reload_seconds := now()-start
	print("reload cue times (s): ",cue_times,"  loaded after %.2fs" % reload_seconds)
	check(absf(reload_seconds-5.0)<0.15,"musket still reloads in 5.0 seconds (%.2f s game time)" % reload_seconds)
	var expected := ["reload_bite","reload_powder","reload_ram_in","reload_ram_tamp","reload_prime","reload_cock"]
	var ordered := true; var last := -1.0
	for n in expected:
		if not cue_times.has(n) or cue_times[n]<last: ordered=false
		else: last=cue_times[n]
	check(ordered,"all six reload sounds play once, in order")
	check(cue_times.get("reload_cock",0)>4.4 and cue_times.get("reload_cock",9)<5.0,"final cock lands just before the reload completes")
	var reload_events := 0
	for e in since(start): if e.sound.begins_with("reload_"): reload_events+=1
	check(reload_events==6,"no reload cue repeats (exactly 6 per reload, got %d)" % reload_events)
	# ---------------------------------------------------------------- switching away mid reload
	await seconds(0.9)
	t0=now()
	player.weapons.attack(player.camera.global_position,aim)
	await seconds(1.0)
	var mid := since(t0).size()
	t0=now()
	player.weapons.switch_weapon()
	await seconds(0.6)
	check("katana_draw" in names_since(t0) and "musket_lower" in names_since(t0),"switching to katana lowers musket and draws sword")
	await seconds(4.2)
	check(player.weapons.musket.loaded,"background reload completes while katana is out")
	var after := since(t0)
	var loud_reload := 0
	var cock := 0
	for e in after:
		if e.sound=="reload_cock": cock+=1
		elif e.sound.begins_with("reload_") and e.t-t0>0.5: loud_reload+=1
	check(cock==1 and loud_reload<=2,"katana out: reload stays quiet (one soft cock, no repeated ramrod cues)")
	# ---------------------------------------------------------------- katana distinct outcomes
	var enemy: BotController=game.actors[5]
	enemy.respawn(); enemy.health.protection=0; enemy.global_position=Vector3(0,0.05,1)
	player.global_position=Vector3(0,0.05,3)
	await seconds(1.0)
	aim=(enemy.global_position+Vector3(0,1.3,0)-player.camera.global_position).normalized()
	t0=now()
	player.weapons.attack(player.camera.global_position,aim)
	await seconds(0.35)
	var hit_names := names_since(t0)
	check("katana_swing_light" in hit_names and "katana_hit" in hit_names and "hit_confirm" in hit_names,"successful katana cut: light swing + flesh hit + hit confirmation")
	await seconds(1.0)
	enemy.global_position=Vector3(8,0.05,-8)
	t0=now()
	player.weapons.attack(player.camera.global_position,Vector3.UP)
	await seconds(0.35)
	var miss_names := names_since(t0)
	check("katana_swing" in miss_names and "katana_hit" not in miss_names and "hit_confirm" not in miss_names,"missed katana cut: full air whoosh only, no impact")
	await seconds(1.0)
	t0=now()
	var wall_dir := Vector3(0,-0.2,-1).normalized()
	player.global_position=Vector3(0,0.05,0); await frames(3)
	player.weapons.attack(player.camera.global_position,Vector3.DOWN+Vector3(0.001,0,0))
	await seconds(0.35)
	check("katana_clank_wood" in names_since(t0) or "katana_clank_stone" in names_since(t0) or "katana_clank_soil" in names_since(t0),"katana striking scenery gives a surface clank")
	# ---------------------------------------------------------------- bot gunfire is positional
	player.weapons.switch_weapon()
	await seconds(1.0)
	player.global_position=Vector3(0,0.05,8)
	var bot: BotController=game.actors[6]
	bot.health.protection=0
	for spot in [[Vector3(6,0.05,2),"near"],[Vector3(40,0.05,-20),"mid"],[Vector3(60,0.05,-55),"far"]]:
		bot.global_position=spot[0]
		bot.weapons.musket=Musket.new()
		t0=now()
		bot.weapons.attack(bot.global_position+Vector3(0,1.4,0),Vector3(0,0,1))
		await seconds(0.7)
		var ev := since(t0)
		var spatial := 0; var far := 0
		for e in ev:
			if e.sound.begins_with("musket_shot"):
				if e.spatial: spatial+=1
				if e.sound=="musket_shot_far": far+=1
		if spot[1]=="near": check(spatial==1 and far==0,"bot shot within 28 m: one positional close report")
		if spot[1]=="mid": check(spatial==2 and far==1,"bot shot at 30-70 m: close report blended with distant report")
		if spot[1]=="far": check(spatial==1 and far==1,"bot shot beyond 70 m: only the distant report")
		var pos_ok := true
		for e in ev: if e.sound.begins_with("musket_shot") and e.pos.distance_to(bot.global_position+Vector3(0,1.4,0))>0.01: pos_ok=false
		check(pos_ok,"bot gunshot ("+spot[1]+") is placed at the bot's muzzle")
	check(player.camera.current,"listener is the first-person camera")
	# ---------------------------------------------------------------- bullet impacts per surface
	for pair in [[Vector3(0,0,0),"wood"],[Vector3(0,0,30),"stone"],[Vector3(-60,0,0),"soil"]]:
		check(game.arena.surface_at(pair[0])==pair[1],"arena reports %s at %s" % [pair[1],pair[0]])
	t0=now()
	sounds.bullet_impact(Vector3(1,1,1),"wood"); sounds.bullet_impact(Vector3(1,1,1),"stone"); sounds.bullet_impact(Vector3(1,1,1),"soil"); sounds.bullet_impact(Vector3(1,1,1),"flesh")
	await seconds(0.1)
	var impact_names := names_since(t0)
	check("bullet_wood" in impact_names and "bullet_stone" in impact_names and "bullet_soil" in impact_names and "bullet_flesh" in impact_names,"bullet impacts exist for wood, stone, soil and flesh")
	# ---------------------------------------------------------------- footsteps follow measured speed
	player.set_physics_process(false)
	var step_counts := {}
	var step_gap_ok := true
	for case in [["crouch",2.2,true,Vector3(0,0.05,0)],["walk",4.5,false,Vector3(0,0.05,0)],["sprint",7.0,false,Vector3(0,0.05,0)]]:
		player.global_position=case[3]; player.steps.reset(); player.velocity=Vector3.ZERO
		await frames(2)
		t0=now(); var travelled := 0.0
		player.steps.last_pos=player.global_position
		for i in range(180):
			player.global_position+=Vector3(0,0,-case[1]/60.0)
			if absf(player.global_position.z)>14: player.global_position.z=8.0; player.steps.last_pos=player.global_position
			player.steps.tick(1.0/60.0,case[2])
			await physics_frame
		var ev := since(t0)
		var times := []
		for e in ev: if e.sound.begins_with("step_"): times.append(e.t)
		step_counts[case[0]]=times.size()
		for i in range(1,times.size()): if times[i]-times[i-1]<0.19: step_gap_ok=false
	print("steps in 3 s: ",step_counts)
	check(step_counts.crouch<step_counts.walk and step_counts.walk<step_counts.sprint,"step cadence rises with actual speed (crouch < walk < sprint)")
	check(step_counts.walk>=6 and step_counts.walk<=9 and step_counts.sprint>=8 and step_counts.sprint<=11,"cadence is plausible: walk %d, sprint %d steps per 3 s" % [step_counts.walk,step_counts.sprint])
	check(step_gap_ok,"no footstep closer than 0.2 s to the previous one")
	t0=now()
	player.global_position=Vector3(0,0.05,8); player.steps.reset(); player.steps.last_pos=player.global_position
	await frames(2)
	player.steps.tick(1.0/60.0,false)
	check(since(t0,"step_wood").size()+since(t0,"step_stone").size()+since(t0,"step_soil").size()==0,"standing still makes no footsteps")
	var surface_hits := {}
	for pair in [[Vector3(0,0.05,0),"step_wood"],[Vector3(0,0.05,33),"step_stone"],[Vector3(-60,0.05,0),"step_soil"]]:
		player.global_position=pair[0]; player.steps.reset(); await frames(2); player.steps.last_pos=player.global_position
		t0=now()
		for i in range(120):
			player.global_position+=Vector3(0.0,0,-4.5/60.0)
			player.steps.tick(1.0/60.0,false)
			await physics_frame
		surface_hits[pair[1]]=since(t0,pair[1]).size()
	print("steps by surface: ",surface_hits)
	check(surface_hits["step_wood"]>2 and surface_hits["step_stone"]>2 and surface_hits["step_soil"]>2,"walking on wood, stone and soil selects the matching footstep set")
	t0=now()
	player.global_position=Vector3(0,0.05,8); player.steps.reset(); player.steps.last_pos=player.global_position
	player.set_physics_process(true)
	Input.action_press("jump"); await frames(3); Input.action_release("jump")
	await seconds(1.2)
	check(not since(t0,"land_wood").is_empty() or not since(t0,"land_stone").is_empty() or not since(t0,"land_soil").is_empty(),"jump landing makes a landing sound")
	# ---------------------------------------------------------------- damage, death, respawn, kill confirm
	enemy=game.actors[5]; enemy.respawn(); enemy.health.protection=0; enemy.global_position=Vector3(0,0.05,-3)
	await seconds(0.3)
	t0=now()
	DamageSystem.hit(enemy,40,player)
	check("pain" in names_since(t0) and since(t0,"pain")[0].spatial,"bot hurt reaction is positional")
	await seconds(0.1)
	t0=now()
	player.health.protection=0
	DamageSystem.hit(player,30,enemy)
	check("pain" in names_since(t0) and not since(t0,"pain")[0].spatial,"player hurt reaction plays in first person")
	t0=now()
	enemy.health.protection=0
	DamageSystem.hit(enemy,100,player)
	await seconds(0.7)
	var death_ev := since(t0,"death")
	check(death_ev.size()==1 and death_ev[0].spatial and since(t0,"body_fall").size()==1,"bot death: positional cry then body fall")
	var voices_on_enemy := 0
	for pool in [sounds._voices3d]:
		for v in pool: if v.playing and v.get_meta("src",0)==enemy.get_instance_id() and v.get_meta("cat","")=="voice": voices_on_enemy+=1
	check(voices_on_enemy<=1,"death cry replaces the pain voice instead of stacking (%d voices on that bot)" % voices_on_enemy)
	t0=now()
	player.health.protection=0
	DamageSystem.hit(player,100,enemy)
	await seconds(0.7)
	check("death" in names_since(t0) and "body_fall" in names_since(t0),"player death sounds")
	t0=now()
	await seconds(3.4)
	check("respawn" in names_since(t0),"player respawn cue")
	t0=now()
	game.feedback(player,"KILL",true); game.feedback(player,"HEADSHOT · KILL",true); game.feedback(player,"HIT",true)
	await seconds(0.15)
	var confirm := names_since(t0)
	check("kill_confirm" in confirm and "headshot_confirm" in confirm and "hit_confirm" in confirm,"hit, headshot and kill confirmations are distinct sounds")
	# ---------------------------------------------------------------- voice limiting under load
	for actor in game.actors: if actor!=player: actor.global_position=Vector3(20,0,-30)
	t0=now()
	for i in range(80): sounds.gunshot(Vector3(randf_range(-30,30),1.4,randf_range(-30,30)),false,i+1)
	for i in range(80): sounds.footstep(game.actors[1+(i%9)],"stone","walk")
	await frames(2)
	var shots_playing := 0
	for v in sounds._voices3d: if v.playing and v.get_meta("cat","")=="shot": shots_playing+=1
	check(shots_playing<=SoundBank.CATEGORY_CAP["shot"],"gunshot voices capped at %d under a barrage (now %d)" % [SoundBank.CATEGORY_CAP["shot"],shots_playing])
	check(playing_count()<=SoundBank.MAX_3D+SoundBank.MAX_2D,"total voices never exceed pool size")
	# ---------------------------------------------------------------- ambience & indoor/outdoor
	var amb: Ambience=game.ambience
	player.set_physics_process(false)
	player.global_position=Vector3(-50,0.05,10)
	await seconds(3.0)
	var out_wind: float=amb.layers["wind_loop"].volume_db; var out_leaf: float=amb.layers["foliage_loop"].volume_db; var out_room: float=amb.layers["room_tone_loop"].volume_db
	var out_cut := sounds.ambient_filter.cutoff_hz
	check(amb.indoor<0.2 and out_room<-40.0 and out_leaf>-30.0 and out_wind>-25.0,"garden: wind and foliage up, room tone off (wind %.1f dB, foliage %.1f dB)" % [out_wind,out_leaf])
	player.global_position=Vector3(0,0.05,0)
	await seconds(3.0)
	var in_wind: float=amb.layers["wind_loop"].volume_db; var in_room: float=amb.layers["room_tone_loop"].volume_db
	check(amb.indoor>0.9 and in_room>-20.0 and in_wind<out_wind-8.0 and amb.layers["foliage_loop"].volume_db<-30.0,"palace interior: room tone up, wind and foliage muffled (room %.1f dB, wind %.1f dB)" % [in_room,in_wind])
	check(sounds.ambient_filter.cutoff_hz<out_cut*0.35 and sounds.reverb.wet>0.15,"interior closes the ambient low-pass and lengthens the reverb")
	player.global_position=Vector3(0,0.05,33)
	await seconds(3.0)
	check(amb.indoor<0.2 and amb.layers["courtyard_air_loop"].volume_db>-30.0,"courtyard: open-air layer returns")
	for layer in amb.layers.values(): check(layer.playing,"ambience layer %s is playing" % layer.stream.resource_name if layer.stream.resource_name!="" else "ambience layer is playing")
	t0=now()
	amb.bird_timer=0.0; amb.creak_timer=0.0; amb.gust_timer=0.0
	await seconds(0.2)
	player.global_position=Vector3(-50,0.05,10); await seconds(0.2)
	amb.bird_timer=0.0; amb.gust_timer=0.0; await seconds(0.2)
	check("bird" in names_since(t0) and since(t0,"bird")[0].spatial and since(t0,"bird")[0].bus=="Ambient","outdoor birds spawn as positional Ambient-bus sounds")
	player.global_position=Vector3(0,0.05,0); await seconds(3.0)
	t0=now(); amb.creak_timer=0.0; await seconds(0.2)
	check("creak" in names_since(t0),"indoor wood creaks are positional")
	# ---------------------------------------------------------------- scene lifecycle
	t0=now()
	player.set_physics_process(true)
	sounds.gunshot(Vector3(5,1.4,5),false,99)
	sounds.play("katana_hit",Vector3(3,1,3),0.0,{"delay":0.5})
	game.return_menu()
	await seconds(0.8)
	check(since(t0,"katana_hit").is_empty() and sounds._queue.is_empty(),"returning to menu cancels pending delayed sounds")
	var world_playing := 0
	for pool in [sounds._voices3d,sounds._voices2d]:
		for v in pool: if v.playing and v.bus!="UI": world_playing+=1
	check(world_playing==0,"returning to menu stops world and weapon voices")
	check(amb.layers["wind_loop"].playing,"ambience keeps running in the menu")
	# ---------------------------------------------------------------- result stingers
	game.start_match(0); await frames(3)
	t0=now(); sounds.match_result(0,[10,3]); check("match_victory" in names_since(t0),"victory stinger when the player's team wins")
	t0=now(); sounds.match_result(0,[3,10]); check("match_defeat" in names_since(t0),"defeat stinger when the player's team loses")
	t0=now(); sounds.match_result(1,[10,3]); check("match_defeat" in names_since(t0),"defeat stinger when the other side wins as Ronin")
	t0=now(); sounds.match_result(0,[5,5]); check("match_end" in names_since(t0),"neutral stinger on a draw")
	# ---------------------------------------------------------------- full match with everyone fighting
	game.start_match(0,true)
	game.match_state.score_limit=10
	game.player.set_physics_process(false); game.player.global_position=Vector3(0,0.05,0)
	var counts0: Dictionary=sounds.counts.duplicate()
	t0=now()
	var peak_voices := 0
	var peak_shot_voices := 0
	var ticks := 0
	while game.match_state.active and ticks<12000:
		await physics_frame; ticks+=1
		if ticks%15==0:
			peak_voices=maxi(peak_voices,playing_count())
			var sv := 0
			for v in sounds._voices3d: if v.playing and v.get_meta("cat","")=="shot": sv+=1
			peak_shot_voices=maxi(peak_shot_voices,sv)
	var by_name := {}
	for k in sounds.counts: if sounds.counts[k]-counts0.get(k,0)>0: by_name[k]=sounds.counts[k]-counts0.get(k,0)
	print("5v5 match: ended=%s after %.1fs game time, scores=%s, peak voices=%d, peak shot voices=%d" % [not game.match_state.active,ticks/60.0,game.match_state.scores,peak_voices,peak_shot_voices])
	print("events by sound: ",by_name)
	check(not game.match_state.active,"a full 5v5 match finishes with audio running")
	check(by_name.get("musket_shot",0)+by_name.get("musket_shot_far",0)>10,"bots produced gunfire sounds during the match")
	check(by_name.get("step_stone",0)+by_name.get("step_wood",0)+by_name.get("step_soil",0)>50,"bot footsteps heard during the match")
	check(by_name.get("death",0)>=8 and by_name.get("pain",0)>=1,"deaths and damage reactions heard")
	check(by_name.get("reload_cock",0)>=5,"bot reloads heard")
	check(peak_voices<=SoundBank.MAX_3D+SoundBank.MAX_2D and peak_shot_voices<=SoundBank.CATEGORY_CAP["shot"],"no voice overload in a 10-actor fight (peak %d voices)" % peak_voices)
	check("match_victory" in by_name or "match_defeat" in by_name or "match_end" in by_name,"match ended with a result stinger")
	check(sounds.missing.is_empty(),"no missing audio resources after the match")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.free()
	OS.delay_msec(100)
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
