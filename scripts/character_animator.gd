class_name CharacterAnimator
extends Node3D
## Provisional articulated rig. Imported rigs use an AnimationPlayer clip adapter;
## original skeleton, meshes, materials and tracks are never rewritten.
const DEATH_DURATION := 1.15
var joints: Dictionary = {}
var phase := 0.0
var crouch_blend := 0.0
var damage_pulse := 0.0
var death_time := -1.0
var death_finished := false
var death_start_position := Vector3.ZERO
var motion_state := "idle"
var weapon_socket: Node3D
var imported_player: AnimationPlayer
var ronin: RoninPresentation
var clip_map := {"idle":"idle", "walk":"walk", "sprint":"sprint", "crouch":"crouch", "crouch_walk":"crouch_walk", "aim":"aim", "fire":"fire", "reload":"reload", "katana_ready":"katana_ready", "katana_attack":"katana_attack", "hit":"hit", "death":"death"}
func joint(key: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.name=key; parent.add_child(n); n.position=pos; joints[key]=n
	return n
func setup(team: int, asset: PackedScene = null) -> void:
	weapon_socket=Node3D.new(); weapon_socket.name="WeaponSocket"; add_child(weapon_socket)
	weapon_socket.position=Vector3(0.27,1.23,-0.22)
	if asset:
		ronin=RoninPresentation.new(); add_child(ronin); ronin.setup(self,asset)
		imported_player=ronin.player
		return
	var cloth := Geometry.mat(Color("191d22") if team==1 else Color("343a40"))
	var armor := Geometry.mat(Color("702f28"),0.55,0.45)
	var trim := Geometry.mat(Color("b69a60"),0.65,0.4)
	var skin := Geometry.mat(Color("b18c72"))
	var torso := joint("torso",self,Vector3(0,0.9,0))
	Geometry.cylinder(torso,Vector3(0,0.25,0),0.27,0.29,0.56,cloth)
	Geometry.cylinder(torso,Vector3.ZERO,0.3,0.31,0.1,trim)
	var head := joint("head",torso,Vector3(0,0.62,0))
	Geometry.cylinder(head,Vector3(0,-0.015,0),0.085,0.095,0.16,skin)
	Geometry.sphere(head,Vector3(0,0.12,0),Vector3(0.32,0.4,0.31),skin)
	for side in [-1,1]:
		var suffix := "left" if side<0 else "right"
		var leg := joint(suffix+"_leg",self,Vector3(side*0.16,0.9,0))
		Geometry.cylinder(leg,Vector3(0,-0.2,0),0.14,0.17,0.4,cloth)
		var knee := joint(suffix+"_knee",leg,Vector3(0,-0.4,0))
		Geometry.cylinder(knee,Vector3(0,-0.2,0),0.13,0.12,0.4,cloth)
		Geometry.box(knee,Vector3(0,-0.39,-0.07),Vector3(0.23,0.16,0.36),cloth)
		var arm := joint(suffix+"_arm",torso,Vector3(side*0.31,0.47,0))
		Geometry.cylinder(arm,Vector3(0,-0.14,0),0.1,0.095,0.28,cloth)
		var elbow := joint(suffix+"_elbow",arm,Vector3(0,-0.28,0))
		Geometry.cylinder(elbow,Vector3(0,-0.13,0),0.09,0.075,0.26,cloth)
		Geometry.sphere(elbow,Vector3(0,-0.27,0),Vector3(0.14,0.18,0.15),skin)
		if team==0:
			for i in range(4): Geometry.box(arm,Vector3(side*0.03,0.025-i*0.055,0),Vector3(0.24,0.048,0.36),armor)
			Geometry.box(torso,Vector3(side*0.13,-0.13,-0.22),Vector3(0.23,0.25,0.08),armor)
	if team==0:
		for i in range(5): Geometry.box(torso,Vector3(0,0.16+i*0.072,-0.24),Vector3(0.49,0.06,0.09),armor)
		Geometry.sphere(head,Vector3(0,0.28,0.025),Vector3(0.4,0.32,0.4),armor)
		Geometry.cylinder(head,Vector3(0,0.2,0.03),0.22,0.24,0.05,armor)
		for side in [-1,1]:
			var horn := Geometry.cylinder(head,Vector3(side*0.2,0.43,-0.02),0,0.035,0.3,trim); horn.rotation.z=-side*0.65
	else:
		Geometry.sphere(head,Vector3(0,0.27,0.025),Vector3(0.34,0.2,0.32),cloth)
		var lapel := Geometry.box(torso,Vector3(0,0.4,-0.255),Vector3(0.055,0.34,0.035),Geometry.mat(Color("777064"))); lapel.rotation.z=0.5
func react() -> void:
	if death_time<0:
		damage_pulse=1.0
		if is_instance_valid(ronin): ronin.hit()
func die() -> void:
	if death_time>=0: return
	death_start_position=position
	death_time=0; death_finished=false; motion_state="death"
	if is_instance_valid(ronin): ronin.die()
	else: _play_clip("death")
func reset_pose() -> void:
	death_time=-1; death_finished=false; damage_pulse=0; crouch_blend=0
	position=Vector3.ZERO; rotation=Vector3.ZERO; scale=Vector3.ONE
	weapon_socket.rotation=Vector3.ZERO
	if is_instance_valid(ronin): ronin.reset_pose()
	for n in joints.values(): n.rotation=Vector3.ZERO
func _play_clip(state: String) -> void:
	if not is_instance_valid(imported_player): return
	var clip: String=clip_map.get(state,state)
	if imported_player.has_animation(clip) and imported_player.current_animation!=clip:
		imported_player.play(clip,0.18)
func pose(key: String, target: Vector3, weight: float) -> void:
	if joints.has(key): joints[key].rotation=joints[key].rotation.lerp(target,weight)
func tick(delta: float, speed: float, crouching: bool, weapon: WeaponController, aiming: bool = true) -> void:
	if is_instance_valid(ronin):
		if death_time>=0:
			death_time+=delta
			position.y=lerpf(death_start_position.y,0,smoothstep(0,0.3,death_time))
		crouch_blend=lerpf(crouch_blend,1.0 if crouching else 0.0,1-exp(-12*delta))
		if death_time<0: position.y=-0.43*crouch_blend
		ronin.tick(delta,speed,crouching,weapon,death_time>=0,aiming)
		motion_state=ronin.state
		death_finished=ronin.death_done
		return
	var blend := 1.0-exp(-12.0*delta)
	if death_time>=0:
		death_time+=delta
		if is_instance_valid(imported_player) and imported_player.has_animation(clip_map.death):
			death_finished=death_time>=maxf(DEATH_DURATION,imported_player.get_animation(clip_map.death).length)
			return
		var fall := smoothstep(0.0,DEATH_DURATION,death_time)
		rotation.x=lerpf(rotation.x,1.48,blend) if death_finished else fall*1.48
		position=death_start_position.lerp(Vector3(0,0.22,0),fall)
		weapon_socket.rotation.x=-fall*1.48
		pose("torso",Vector3(-0.15,0,0.1),blend)
		pose("left_arm",Vector3(0.1,0,-0.8),blend); pose("right_arm",Vector3(0.25,0,0.7),blend)
		pose("left_knee",Vector3(0.25,0,0),blend); pose("right_knee",Vector3(0.45,0,0),blend)
		death_finished=death_time>=DEATH_DURATION
		return
	phase+=delta*(11.0 if speed>5 else 7.0)
	crouch_blend=lerpf(crouch_blend,1.0 if crouching else 0.0,blend)
	damage_pulse=maxf(0,damage_pulse-delta*3.5)
	var moving := clampf(speed/4.5,0,1)
	var stride := sin(phase)*moving*(0.8 if speed>5 else 0.48)*(1-crouch_blend*0.5)
	position.y=-0.43*crouch_blend+absf(sin(phase))*moving*0.025
	motion_state="crouch_walk" if crouching and speed>0.1 else ("crouch" if crouching else ("sprint" if speed>5 else ("walk" if speed>0.1 else "idle")))
	var gun := weapon.selected==0
	var loading := weapon.musket.remaining>0 and gun
	var reload_wave := sin((1.0-weapon.musket.remaining/Musket.RELOAD_TIME)*PI*6) if loading else 0.0
	var action := weapon.animation/0.65
	if moving<0.1 and not crouching: motion_state="reload" if loading else ("aim" if gun and aiming else ("katana_ready" if not gun else "idle"))
	if weapon.recoil>0.2: motion_state="fire"
	if action>0: motion_state="katana_attack"
	if damage_pulse>0: motion_state="hit"
	_play_clip(motion_state)
	pose("torso",Vector3(-0.1*crouch_blend+sin(phase*0.4)*0.012+damage_pulse*0.22,action*0.45,damage_pulse*0.12),blend)
	pose("left_leg",Vector3(stride-0.55*crouch_blend,0,-0.03),blend)
	pose("right_leg",Vector3(-stride-0.55*crouch_blend,0,0.03),blend)
	pose("left_knee",Vector3(maxf(0,-stride)*0.7+1.0*crouch_blend,0,0),blend)
	pose("right_knee",Vector3(maxf(0,stride)*0.7+1.0*crouch_blend,0,0),blend)
	pose("left_arm",Vector3(1.05+reload_wave*0.25 if gun else 0.65+action*1.2,0,-0.2),blend)
	pose("right_arm",Vector3(1.25+weapon.recoil*0.3 if gun else 0.85+action*1.1,-action*0.8,0.12+action*0.6),blend)
	pose("left_elbow",Vector3(0.55+reload_wave*0.45,0,0),blend)
	pose("right_elbow",Vector3(0.35,0,0),blend)
	weapon_socket.position=Vector3(0.27,1.23, -0.22)+Vector3(0,sin(phase)*moving*0.015,0)

func head_position() -> Vector3:
	if is_instance_valid(ronin): return ronin.head_position()
	return Vector3(0,1.64+position.y,0)
