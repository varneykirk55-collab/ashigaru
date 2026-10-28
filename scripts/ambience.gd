class_name Ambience
extends Node
## Layered palace soundscape. Loops crossfade smoothly with where the player stands
## (garden / courtyard / palace interior); birds, creaks and wind gusts are positional one-shots.
## No music, no synthetic "distant battle" - far combat is the real gunfire of the bots (SoundBank far samples).
## Loop files are normalised to about -26..-32 dB RMS; these offsets set the final bed level (about -33 dB RMS outdoors, measured in the mix).
const LAYER_DB := {"wind_loop": -4.0, "foliage_loop": -8.0, "courtyard_air_loop": -6.0, "room_tone_loop": -4.0}
const MAP_LIMIT := 68.0
var game: Node3D
var sounds: SoundBank
var layers := {}              # name -> AudioStreamPlayer
var weights := {"wind_loop": 0.0, "foliage_loop": 0.0, "courtyard_air_loop": 0.0, "room_tone_loop": 0.0}
var indoor := 0.0
var garden := 0.0
var courtyard := 0.0
var bird_timer := 3.0
var creak_timer := 9.0
var gust_timer := 12.0
var last_bird := -1
func setup(g: Node3D) -> void:
	game = g; sounds = g.sounds
	for name in LAYER_DB:
		var p := AudioStreamPlayer.new(); add_child(p)
		p.bus = SoundBank.BUS_AMBIENT
		p.stream = sounds.loop_stream(name)
		p.volume_db = -60.0
		p.play(sounds.rng.randf() * 4.0)
		layers[name] = p
	_update_zone(1.0, true)
func anchor() -> Vector3:
	return game.player.global_position if is_instance_valid(game.player) and game.match_state.active else Vector3(0, 0, 0)
func _update_zone(delta: float, snap := false) -> void:
	var pos := anchor()
	var p2 := Vector2(pos.x, pos.z)
	var surface: String = game.arena.surface_at(pos)
	var d: Dictionary = game.arena.districts
	var target_in := 1.0 if d.palace.has_point(p2) else (0.35 if surface == "wood" else 0.0)
	var target_garden := 1.0 if (d.west_garden.has_point(p2) or d.east_garden.has_point(p2)) else 0.35
	var target_court := 1.0 if d.courtyard.has_point(p2) else 0.2
	var k := 1.0 if snap else clampf(delta * 2.2, 0.0, 1.0)
	indoor = lerpf(indoor, target_in, k)
	garden = lerpf(garden, target_garden, k)
	courtyard = lerpf(courtyard, target_court, k)
	var out := 1.0 - indoor
	# wind persists faintly indoors (through screens); foliage and open air do not
	weights["wind_loop"] = lerpf(0.28, 1.0, out) * lerpf(0.75, 1.0, courtyard)
	weights["foliage_loop"] = out * lerpf(0.4, 1.0, garden)
	weights["courtyard_air_loop"] = out * lerpf(0.3, 1.0, courtyard)
	weights["room_tone_loop"] = indoor
	for name in layers:
		layers[name].volume_db = LAYER_DB[name] + linear_to_db(maxf(weights[name], 0.001))
	sounds.set_indoor(indoor)
func _process(delta: float) -> void:
	if not is_instance_valid(game) or game.paused: return
	_update_zone(delta)
	var out := 1.0 - indoor
	bird_timer -= delta; creak_timer -= delta; gust_timer -= delta
	if bird_timer <= 0:
		bird_timer = sounds.rng.randf_range(4.0, 11.0) / maxf(0.35, lerpf(0.5, 1.2, garden))
		if out > 0.6: _bird()
	if creak_timer <= 0:
		creak_timer = sounds.rng.randf_range(8.0, 20.0)
		if indoor > 0.3: _creak()
	if gust_timer <= 0:
		gust_timer = sounds.rng.randf_range(16.0, 32.0)
		if out > 0.5: _gust()
func _ring_point(min_r: float, max_r: float, y: float) -> Vector3:
	var a := sounds.rng.randf() * TAU
	var r := sounds.rng.randf_range(min_r, max_r)
	var c := anchor()
	var p := c + Vector3(cos(a) * r, y, sin(a) * r)
	p.x = clampf(p.x, -MAP_LIMIT, MAP_LIMIT); p.z = clampf(p.z, -MAP_LIMIT, MAP_LIMIT)
	return p
func _bird() -> void:
	var variant := sounds.rng.randi() % 6
	if variant == last_bird: variant = (variant + 1) % 6
	last_bird = variant
	var pos := _ring_point(14.0, 48.0, sounds.rng.randf_range(5.0, 11.0))
	sounds.play("bird", pos, sounds.rng.randf_range(-10.0, -3.0), {"bus": SoundBank.BUS_AMBIENT, "priority": 1, "category": "bird", "unit": 8.0, "max_distance": 90.0, "cutoff": 4500.0, "pitch": sounds.rng.randf_range(0.92, 1.12), "jitter": 0.0})
func _creak() -> void:
	sounds.creak(_ring_point(3.0, 9.0, sounds.rng.randf_range(0.2, 2.5)), -3.0)
func _gust() -> void:
	sounds.play("wind_gust", _ring_point(10.0, 25.0, 3.0), -6.0, {"bus": SoundBank.BUS_AMBIENT, "priority": 1, "category": "gust", "unit": 12.0, "max_distance": 80.0, "pitch": sounds.rng.randf_range(0.9, 1.1)})
func _exit_tree() -> void:
	for p in layers.values():
		if is_instance_valid(p): p.stop()
