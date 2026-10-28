class_name SoundBank
extends Node
## Central audio service. Gameplay code never touches players or buses directly; it reports
## events (gunshot, reload stage, footstep ...) and this class decides how they sound:
## bus routing, voice pooling/limits, distance behaviour, variation and delays.
##
## Buses (created at runtime so the project needs no bus-layout file):
##   Master  - hard limiter (no clipping)
##   SFX     - compressor + dynamic room reverb (all world + weapon sounds)
##   Ambient - low-pass that closes indoors (wind, foliage, room tone, birds, creaks)
##   UI      - menu / match stingers, follows the SFX slider
## Adding a weapon or map later only needs new CATALOG entries and one event method.

const ROOT := "res://assets/audio/"
const BUS_SFX := "SFX"
const BUS_AMBIENT := "Ambient"
const BUS_UI := "UI"
const MAX_3D := 28
const MAX_2D := 10
const SPEED_OF_SOUND := 343.0
const SFX_TRIM_DB := 3.0   # headroom trade: weapons need to hit hard, ambience stays on its own bus

## name -> [folder, variant count]. One variant -> "<name>.wav"; several -> "<name>_1.wav" ...
const CATALOG := {
	"musket_shot": ["weapons", 3], "musket_shot_far": ["weapons", 2],
	"musket_dry_fire": ["weapons", 1], "musket_not_ready": ["weapons", 1],
	"reload_bite": ["weapons", 2], "reload_powder": ["weapons", 2], "reload_ram_in": ["weapons", 2],
	"reload_ram_tamp": ["weapons", 2], "reload_prime": ["weapons", 2], "reload_cock": ["weapons", 2],
	"musket_raise": ["weapons", 1], "musket_lower": ["weapons", 1],
	"katana_draw": ["weapons", 2], "katana_swing": ["weapons", 3], "katana_swing_light": ["weapons", 3],
	"katana_hit": ["weapons", 3],
	"katana_clank_wood": ["weapons", 2], "katana_clank_stone": ["weapons", 2], "katana_clank_soil": ["weapons", 2],
	"bullet_wood": ["impacts", 3], "bullet_stone": ["impacts", 3], "bullet_soil": ["impacts", 3], "bullet_flesh": ["impacts", 2],
	"step_wood": ["footsteps", 5], "step_stone": ["footsteps", 5], "step_soil": ["footsteps", 5],
	"land_wood": ["footsteps", 2], "land_stone": ["footsteps", 2], "land_soil": ["footsteps", 2],
	"cloth_move": ["footsteps", 2],
	"pain": ["character", 3], "death": ["character", 2], "body_fall": ["character", 1], "respawn": ["character", 1],
	"ui_hover": ["ui", 1], "ui_click": ["ui", 1], "ui_confirm": ["ui", 1], "ui_back": ["ui", 1], "ui_tick": ["ui", 1],
	"ui_pause": ["ui", 1], "hit_confirm": ["ui", 1], "headshot_confirm": ["ui", 1], "kill_confirm": ["ui", 1],
	"match_start": ["ui", 1], "match_victory": ["ui", 1], "match_defeat": ["ui", 1], "match_end": ["ui", 1],
	"bird": ["ambience", 6], "creak": ["ambience", 4], "wind_gust": ["ambience", 1],
	"wind_loop": ["ambience", 1], "foliage_loop": ["ambience", 1],
	"room_tone_loop": ["ambience", 1], "courtyard_air_loop": ["ambience", 1],
}
## Max simultaneous voices per category; beyond that the oldest of the same category is replaced.
const CATEGORY_CAP := {"shot": 6, "step": 6, "reload": 4, "swing": 4, "impact": 6, "voice": 5, "bird": 2, "creak": 2, "ui": 3, "gust": 1}
const RELOAD_SOUNDS := {
	"reload_bite": 0.0, "reload_powder": 0.0, "reload_ram_in": 0.0, "reload_ram_tamp": 0.0, "reload_prime": 0.0, "reload_cock": -3.0
}

var volumes := {"master": 0.9, "sfx": 1.0, "ambient": 0.8}
## Legacy single volume slider == master.
var volume: float:
	get: return volumes["master"]
	set(v): set_volume("master", v)

var events: Array = []   # recent events, used by tests and debugging
var counts := {}                      # sound name -> times started
var rejected := {}                    # reason -> times a sound was dropped (voice limits)
var missing: Array[String] = []
var reverb: AudioEffectReverb
var ambient_filter: AudioEffectLowPassFilter

var _streams := {}
var _last_variant := {}
var _voices3d: Array[AudioStreamPlayer3D] = []
var _voices2d: Array[AudioStreamPlayer] = []
var _queue: Array[Dictionary] = []
var _cooldowns := {}
## Private generator: audio variation must never consume the global RNG that bot behaviour (and its tests) rely on.
var rng := RandomNumberGenerator.new()
var _clock := 0.0   # game-time seconds (follows fixed-step runs and movie capture, not the wall clock)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_buses()
	for i in range(MAX_3D):
		var p := AudioStreamPlayer3D.new(); add_child(p); _voices3d.append(p)
	for i in range(MAX_2D):
		var p := AudioStreamPlayer.new(); add_child(p); _voices2d.append(p)
	for sound in CATALOG:
		_variants(sound)
	_apply_volumes()


func _exit_tree() -> void:
	for pool in [_voices3d, _voices2d]:
		for p in pool:
			if is_instance_valid(p):
				p.stop()
				p.stream = null
	_queue.clear()


func _process(delta: float) -> void:
	_clock += delta
	if _queue.is_empty(): return
	var now := _clock
	var keep: Array[Dictionary] = []
	for item in _queue:
		if item.due <= now: _start(item.sound, item.pos, item.db, item.opts)
		else: keep.append(item)
	_queue = keep


# ------------------------------------------------------------------------------ buses & volume
func _setup_buses() -> void:
	for n in [BUS_SFX, BUS_AMBIENT, BUS_UI]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0; limiter.pre_gain_db = 0.0
		AudioServer.add_bus_effect(0, limiter)
	var sfx := AudioServer.get_bus_index(BUS_SFX)
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -6.0; comp.ratio = 2.0; comp.attack_us = 20.0; comp.release_ms = 200.0
		AudioServer.add_bus_effect(sfx, comp)
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.3; rv.damping = 0.6; rv.wet = 0.07; rv.dry = 1.0; rv.spread = 1.0
		AudioServer.add_bus_effect(sfx, rv)
	reverb = AudioServer.get_bus_effect(sfx, 1) as AudioEffectReverb
	var amb := AudioServer.get_bus_index(BUS_AMBIENT)
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lpf := AudioEffectLowPassFilter.new(); lpf.cutoff_hz = 16000.0
		AudioServer.add_bus_effect(amb, lpf)
	ambient_filter = AudioServer.get_bus_effect(amb, 0) as AudioEffectLowPassFilter


func set_volume(key: String, v: float) -> void:
	volumes[key] = clampf(v, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus("Master", volumes["master"])
	_set_bus(BUS_SFX, volumes["sfx"], SFX_TRIM_DB)
	_set_bus(BUS_UI, volumes["sfx"], SFX_TRIM_DB)
	_set_bus(BUS_AMBIENT, volumes["ambient"])


func _set_bus(bus: String, linear: float, trim_db := 0.0) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1: return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)) + trim_db)


## Indoor amount 0..1 drives the room reverb and ambient muffling (called by Ambience).
func set_indoor(amount: float) -> void:
	if reverb:
		reverb.room_size = lerpf(0.3, 0.62, amount)
		reverb.wet = lerpf(0.07, 0.2, amount)
		reverb.damping = lerpf(0.6, 0.45, amount)
	if ambient_filter:
		ambient_filter.cutoff_hz = lerpf(16000.0, 2600.0, amount)


# ------------------------------------------------------------------------------ core playback
func _variants(sound: String) -> Array:
	if _streams.has(sound): return _streams[sound]
	var entry: Array = CATALOG.get(sound, [])
	var list := []
	if entry.is_empty():
		missing.append(sound)
	else:
		for i in range(1, entry[1] + 1):
			var path: String = ROOT + entry[0] + "/" + sound + (".wav" if entry[1] == 1 else "_%d.wav" % i)
			var s := load(path) as AudioStream
			if s == null: missing.append(path)
			else: list.append(s)
	_streams[sound] = list
	return list


func stream_for(sound: String) -> AudioStream:
	var list := _variants(sound)
	if list.is_empty(): return null
	var idx := rng.randi() % list.size()
	if list.size() > 1 and idx == _last_variant.get(sound, -1): idx = (idx + 1) % list.size()
	_last_variant[sound] = idx
	return list[idx]


## Looping stream with explicit loop points (a runtime-set loop_mode alone needs loop_end).
func loop_stream(sound: String) -> AudioStream:
	var base := stream_for(sound) as AudioStreamWAV
	if base == null: return null
	var s := base.duplicate() as AudioStreamWAV
	var bytes := 2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / bytes / (2 if s.stereo else 1)
	return s


## General entry point. opts: delay, bus, priority, category, source, pitch, jitter, unit, max_distance, cutoff.
func play(sound: String, pos := Vector3.INF, db := 0.0, opts := {}) -> bool:
	var delay: float = opts.get("delay", 0.0)
	if delay > 0.0:
		var o := opts.duplicate(); o.erase("delay")
		_queue.append({"due": _clock + delay, "sound": sound, "pos": pos, "db": db, "opts": o})
		return true
	return _start(sound, pos, db, opts)


func _start(sound: String, pos: Vector3, db: float, opts: Dictionary) -> bool:
	var stream := stream_for(sound)
	if stream == null: return false
	var category: String = opts.get("category", "")
	var priority: int = opts.get("priority", 3)
	var source: int = opts.get("source", 0)
	var spatial := pos != Vector3.INF
	if category != "":
		if source != 0 and category == "voice": _stop_matching(category, source, 0.04)
		var cap: int = CATEGORY_CAP.get(category, 99)
		var same := _playing_in(category)
		if same.size() >= cap:
			var oldest = same[0]
			for v in same:
				if v.get_meta("t") < oldest.get_meta("t"): oldest = v
			if oldest.get_meta("prio") > priority:
				rejected["category_full"] = rejected.get("category_full", 0) + 1
				return false
			oldest.stop()
	var voice = _acquire(spatial, priority)
	if voice == null:
		rejected["pool_full"] = rejected.get("pool_full", 0) + 1
		return false
	voice.stream = stream
	voice.bus = opts.get("bus", BUS_SFX)
	voice.volume_db = db
	var jitter: float = opts.get("jitter", 0.035)
	voice.pitch_scale = opts.get("pitch", 1.0) * (1.0 + rng.randf_range(-jitter, jitter))
	voice.set_meta("prio", priority); voice.set_meta("cat", category)
	voice.set_meta("src", source); voice.set_meta("t", _clock)
	if spatial:
		voice.unit_size = opts.get("unit", 8.0)
		voice.max_distance = opts.get("max_distance", 60.0)
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.attenuation_filter_cutoff_hz = opts.get("cutoff", 5000.0)
		voice.panning_strength = opts.get("pan", 2.0)   # engine default is weak (about 5 dB at 55 degrees); 2.0 gives clear left/right
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		voice.global_position = pos
	voice.play()
	counts[sound] = counts.get(sound, 0) + 1
	events.append({"t": _clock, "sound": sound, "pos": pos, "db": db, "bus": voice.bus, "spatial": spatial, "source": source})
	if events.size() > 600: events = events.slice(300)
	return true


func _acquire(spatial: bool, priority: int):
	var pool = _voices3d if spatial else _voices2d
	for v in pool:
		if not v.playing: return v
	var weakest = null
	for v in pool:
		if v.get_meta("prio", 0) <= priority and (weakest == null or v.get_meta("prio", 0) < weakest.get_meta("prio", 0)
				or (v.get_meta("prio", 0) == weakest.get_meta("prio", 0) and v.get_meta("t", 0) < weakest.get_meta("t", 0))):
			weakest = v
	if weakest != null: weakest.stop()
	return weakest


func _playing_in(category: String) -> Array:
	var list := []
	for pool in [_voices3d, _voices2d]:
		for v in pool:
			if v.playing and v.get_meta("cat", "") == category: list.append(v)
	return list


func _stop_matching(category: String, source: int, fade: float) -> void:
	for pool in [_voices3d, _voices2d]:
		for v in pool:
			if v.playing and v.get_meta("src", 0) == source and (category == "" or v.get_meta("cat", "") == category):
				_fade_stop(v, fade)


func _fade_stop(voice: Node, fade: float) -> void:
	var t := create_tween()
	t.tween_property(voice, "volume_db", -60.0, fade)
	t.tween_callback(voice.stop)


## Silence every world/weapon/ambient voice and cancel pending delayed sounds (match start, return to menu).
func reset_world() -> void:
	_queue.clear()
	for pool in [_voices3d, _voices2d]:
		for v in pool:
			if v.playing and v.bus != BUS_UI: v.stop()


func listener_position() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _is_player(actor: Node) -> bool:
	return actor is PlayerController


func _cool(key: String, seconds: float) -> bool:
	var now := _clock
	if now < _cooldowns.get(key, 0.0): return false
	_cooldowns[key] = now + seconds
	return true


func _delay_for(pos: Vector3, max_delay := 0.3) -> float:
	var d := listener_position().distance_to(pos)
	return minf(d / SPEED_OF_SOUND, max_delay) if d > 14.0 else 0.0


# ------------------------------------------------------------------------------ musket
## Own shots are non-positional and clear; everyone else is positional with a close/far hand-off.
func gunshot(pos: Vector3, own: bool, source := 0) -> void:
	if own:
		play("musket_shot", Vector3.INF, -3.0, {"priority": 10, "category": "shot", "jitter": 0.02})
		return
	var d := listener_position().distance_to(pos)
	if d < 28.0:
		play("musket_shot", pos, 0.0, {"priority": 8, "category": "shot", "unit": 10.0, "max_distance": 170.0, "source": source, "cutoff": 8000.0})
	elif d < 70.0:
		var fade := (d - 28.0) / 42.0
		play("musket_shot", pos, -9.0 * fade, {"priority": 6, "category": "shot", "unit": 10.0, "max_distance": 170.0, "cutoff": 6000.0, "delay": minf(d / SPEED_OF_SOUND * 0.5, 0.15)})
		play("musket_shot_far", pos, -7.0 + 3.0 * fade, {"priority": 6, "category": "shot", "unit": 14.0, "max_distance": 260.0, "cutoff": 4000.0, "delay": minf(d / SPEED_OF_SOUND, 0.3)})
	else:
		play("musket_shot_far", pos, -4.0, {"priority": 5, "category": "shot", "unit": 14.0, "max_distance": 260.0, "cutoff": 3500.0, "delay": minf(d / SPEED_OF_SOUND, 0.45)})


func dry_fire(reloading: bool) -> void:
	if not _cool("dry", 0.3): return
	play("musket_not_ready" if reloading else "musket_dry_fire", Vector3.INF, 0.0, {"priority": 7})


## stage = one of the reload_* sounds; cues are driven by the real reload timer in WeaponController.
func reload_cue(stage: String, actor: Node3D, equipped: bool) -> void:
	var db: float = RELOAD_SOUNDS.get(stage, 0.0)
	if not equipped:
		# Musket reloading in the background while the katana is out: only the final cock is heard, softly.
		if stage != "reload_cock": return
		db -= 9.0
	var source := actor.get_instance_id()
	if _is_player(actor):
		play(stage, Vector3.INF, db - 6.0, {"priority": 6, "category": "reload", "source": source})
	else:
		play(stage, actor.global_position + Vector3(0, 1.1, 0), db - 7.0, {"priority": 3, "category": "reload", "source": source, "unit": 3.0, "max_distance": 30.0, "cutoff": 4000.0})


func weapon_switch(actor: Node3D, to_katana: bool) -> void:
	var source := actor.get_instance_id()
	if not _cool("switch%d" % source, 0.45): return
	if to_katana: _stop_matching("reload", source, 0.08)   # no half-finished ramrod sound over the draw
	var sound := "katana_draw" if to_katana else "musket_raise"
	if _is_player(actor):
		if to_katana: play("musket_lower", Vector3.INF, -4.0, {"priority": 5})
		play(sound, Vector3.INF, -2.0, {"priority": 6, "delay": 0.14})
	else:
		play(sound, actor.global_position + Vector3(0, 1.1, 0), -3.0, {"priority": 3, "delay": 0.14, "unit": 3.5, "max_distance": 30.0})


# ------------------------------------------------------------------------------ katana & impacts
## outcome: "miss" (full air cut), "flesh" (connected), "world" (struck scenery).
func katana_attack(actor: Node3D, origin: Vector3, outcome: String, hit_pos: Vector3, surface: String) -> void:
	var own := _is_player(actor)
	var swing_sound := "katana_swing" if outcome == "miss" else "katana_swing_light"
	var swing_db := -3.0 if outcome == "miss" else -8.0
	if own:
		play(swing_sound, Vector3.INF, swing_db - 1.0, {"priority": 6, "category": "swing", "delay": 0.07})
	else:
		play(swing_sound, origin, swing_db, {"priority": 4, "category": "swing", "delay": 0.07, "unit": 4.0, "max_distance": 38.0})
	if outcome == "flesh":
		play("katana_hit", hit_pos, -4.0, {"priority": 8, "category": "impact", "delay": 0.2, "unit": 5.0, "max_distance": 45.0})
	elif outcome == "world":
		play("katana_clank_" + surface, hit_pos, -5.0, {"priority": 7, "category": "impact", "delay": 0.2, "unit": 5.0, "max_distance": 45.0})


func bullet_impact(pos: Vector3, surface: String) -> void:
	play("bullet_" + surface, pos, 0.0, {"priority": 5, "category": "impact", "unit": 6.0, "max_distance": 90.0, "delay": _delay_for(pos), "cutoff": 6000.0})


# ------------------------------------------------------------------------------ character
func footstep(actor: Node3D, surface: String, mode: String) -> void:
	var pitch := 1.06 if mode == "sprint" else (0.93 if mode == "crouch" else 1.0)
	if _is_player(actor):
		var db := -21.0 if mode == "crouch" else (-9.0 if mode == "sprint" else -13.0)
		play("step_" + surface, Vector3.INF, db, {"priority": 4, "category": "step", "pitch": pitch})
	else:
		var db := -6.0 if mode == "sprint" else -8.0
		play("step_" + surface, actor.global_position, db, {"priority": 2, "category": "step", "pitch": pitch, "unit": 3.0, "max_distance": 34.0, "cutoff": 3200.0})


func landing(actor: Node3D, surface: String) -> void:
	if _is_player(actor):
		play("land_" + surface, Vector3.INF, -7.0, {"priority": 5, "category": "step"})
	else:
		play("land_" + surface, actor.global_position, -6.0, {"priority": 3, "category": "step", "unit": 4.0, "max_distance": 38.0})


func crouch_move(actor: Node3D) -> void:
	if _is_player(actor): play("cloth_move", Vector3.INF, -8.0, {"priority": 2})


func damage_cue(actor: Node3D) -> void:
	var source := actor.get_instance_id()
	if not _cool("pain%d" % source, 0.3): return
	if _is_player(actor):
		play("pain", Vector3.INF, -6.0, {"priority": 7, "category": "voice", "source": source})
	else:
		play("pain", actor.global_position + Vector3(0, 1.5, 0), -4.0, {"priority": 5, "category": "voice", "source": source, "unit": 4.0, "max_distance": 42.0})


func death_cue(actor: Node3D) -> void:
	var source := actor.get_instance_id()
	if _is_player(actor):
		play("death", Vector3.INF, -8.0, {"priority": 9, "category": "voice", "source": source})
		play("body_fall", Vector3.INF, -7.0, {"priority": 6, "delay": 0.55})
	else:
		var p := actor.global_position
		play("death", p + Vector3(0, 1.4, 0), -5.0, {"priority": 7, "category": "voice", "source": source, "unit": 4.5, "max_distance": 48.0})
		play("body_fall", p, -2.0, {"priority": 5, "delay": 0.55, "unit": 4.0, "max_distance": 40.0})


func respawn_cue() -> void:
	play("respawn", Vector3.INF, -2.0, {"priority": 6})


func creak(pos: Vector3, db := -4.0) -> void:
	play("creak", pos, db, {"bus": BUS_AMBIENT, "priority": 1, "category": "creak", "unit": 3.0, "max_distance": 26.0, "cutoff": 3500.0})


# ------------------------------------------------------------------------------ UI & match
func ui(sound: String, db := 0.0) -> void:
	if db == 0.0: db = -9.0 if (sound == "ui_hover" or sound == "ui_tick") else -5.0
	var gap := 0.05 if sound == "ui_hover" or sound == "ui_tick" else 0.0
	if gap > 0.0 and not _cool(sound, gap * 1.6): return
	play(sound, Vector3.INF, db, {"bus": BUS_UI, "priority": 8, "category": "ui", "jitter": 0.0})


## kind: "hit", "headshot", "kill" (confirmation for the local player's own damage).
func hit_confirm(kind: String, delay := 0.0) -> void:
	var sound := "hit_confirm"
	if kind.contains("KILL"): sound = "kill_confirm"
	elif kind.contains("HEADSHOT"): sound = "headshot_confirm"
	play(sound, Vector3.INF, -5.0, {"priority": 9, "delay": delay, "jitter": 0.0})
	if sound == "kill_confirm" and kind.contains("HEADSHOT"):
		play("headshot_confirm", Vector3.INF, -8.0, {"priority": 9, "delay": delay + 0.03, "jitter": 0.0})


func match_result(player_team: int, scores: Array) -> void:
	var sound := "match_end"
	if scores[0] != scores[1]:
		var winner := 0 if scores[0] > scores[1] else 1
		sound = "match_victory" if winner == player_team else "match_defeat"
	ui(sound, -1.0)
