class_name FootstepEmitter
extends RefCounted
## Turns an actor's real displacement into footsteps, crouch shuffles and landings.
## Cadence follows measured ground speed (not input), so walls, slopes and bot pathing sound right.
const MIN_GAP := 0.2
var actor: CharacterBody3D
var game: Node3D
var last_pos := Vector3.INF
var stride := 0.0
var since := 9.0
var was_on_floor := true
var air_vy := 0.0
var land_cooldown := 0.0
var was_crouching := false
var creak_cooldown := 0.0
func _init(a: CharacterBody3D, g: Node3D) -> void:
	actor = a; game = g
func reset() -> void:
	last_pos = Vector3.INF; stride = 0.0; air_vy = 0.0; was_on_floor = true
func tick(delta: float, crouching: bool) -> void:
	var pos := actor.global_position
	if last_pos == Vector3.INF:
		last_pos = pos; return
	var moved := Vector2(pos.x - last_pos.x, pos.z - last_pos.z).length()
	last_pos = pos
	since += delta; land_cooldown = maxf(0, land_cooldown - delta); creak_cooldown = maxf(0, creak_cooldown - delta)
	if moved > 2.5:   # respawn / teleport, not walking
		stride = 0.0; return
	var surface: String = game.arena.surface_at(pos)
	var on_floor := actor.is_on_floor()
	if not on_floor:
		air_vy = minf(air_vy, actor.velocity.y)
	elif not was_on_floor:
		if -air_vy > 4.5 and land_cooldown <= 0:
			game.sounds.landing(actor, surface); land_cooldown = 0.4
		air_vy = 0.0
	elif air_vy != 0.0:
		air_vy = 0.0
	was_on_floor = on_floor
	if crouching != was_crouching:
		game.sounds.crouch_move(actor)
		was_crouching = crouching
	var speed := moved / maxf(delta, 0.0001)
	var length := 1.25 if crouching else (2.15 if speed > 5.5 else 1.8)
	if not on_floor: return
	if speed < 0.5:
		stride = maxf(stride, length * 0.55)   # first step lands quickly after starting to move
		return
	stride += moved
	if stride >= length and since >= MIN_GAP:
		stride = minf(stride - length, length * 0.5); since = 0.0
		var mode := "crouch" if crouching else ("sprint" if speed > 5.5 else "walk")
		game.sounds.footstep(actor, surface, mode)
		if surface == "wood" and creak_cooldown <= 0 and game.sounds.rng.randf() < 0.06:
			creak_cooldown = 6.0
			game.sounds.creak(pos + Vector3(game.sounds.rng.randf_range(-1.5, 1.5), 0.2, game.sounds.rng.randf_range(-1.5, 1.5)), -5.0 if actor is PlayerController else -9.0)
