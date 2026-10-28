class_name RoninPresentation
extends Node3D
## Non-destructive adapter for the supplied skinned GLB and its original clips.
const CLIPS := {"idle":"Idle","walk":"Walk","sprint":"Run","aim":"Musket_Aim","fire":"Musket_Fire","reload":"Musket_Reload","katana_ready":"Idle","katana_attack":"Katana_Slash","hit":"Hit_React","death":"Death","crouch":"Musket_Aim","crouch_walk":"Walk"}
var skeleton: Skeleton3D
var player: AnimationPlayer
var locomotion_player: AnimationPlayer
var action_kind := "fire"
var visual: Node3D
var state := ""
var state_time := 0.0
var previous_recoil := 0.0
var previous_attack := 0.0
var hit_left := 0.0
var action_left := 0.0
var death_done := false
var aim_weight := 0.0
var lower_hand_error := 0.0
var owner_animator: CharacterAnimator
var head_bone := -1
var right_bone := -1
var left_bone := -1
var arm_left := -1
var arm_right := -1
var crouch_weight := 0.0
var death_start_pose: Dictionary = {}
var aim_pose: Dictionary = {}
var ready_pose: Dictionary = {}
var last_arm_rotations: Dictionary = {}
func setup(root: CharacterAnimator, asset: PackedScene) -> void:
	owner_animator=root
	visual=asset.instantiate(); add_child(visual); visual.rotation.y=PI
	skeleton=visual.find_children("*","Skeleton3D",true,false)[0]
	player=visual.find_children("*","AnimationPlayer",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Duplicate animation resources before changing looping metadata. Source keyframes stay intact.
	for library_name in player.get_animation_library_list():
		var original := player.get_animation_library(library_name)
		var library := AnimationLibrary.new()
		for name in original.get_animation_list():
			var clip: Animation=original.get_animation(name).duplicate()
			if name in ["Idle","Walk","Run","Musket_Aim"]: clip.loop_mode=Animation.LOOP_LINEAR
			library.add_animation(name,clip)
		player.remove_animation_library(library_name); player.add_animation_library(library_name,library)
	locomotion_player=AnimationPlayer.new(); player.get_parent().add_child(locomotion_player)
	locomotion_player.root_node=player.root_node
	locomotion_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for library_name in player.get_animation_library_list(): locomotion_player.add_animation_library(library_name,player.get_animation_library(library_name))
	head_bone=skeleton.find_bone("head"); right_bone=skeleton.find_bone("hand_r"); left_bone=skeleton.find_bone("hand_l")
	arm_left=skeleton.find_bone("upperarm_l"); arm_right=skeleton.find_bone("upperarm_r")
	player.play("Musket_Aim"); player.seek(0.75,true); player.advance(0)
	for bone in range(skeleton.get_bone_count()):
		if _upper_body(bone): aim_pose[bone]=[skeleton.get_bone_pose_position(bone),skeleton.get_bone_pose_rotation(bone)]
	player.play("Katana_Slash"); player.seek(0,true); player.advance(0)
	for bone in aim_pose: ready_pose[bone]=[skeleton.get_bone_pose_position(bone),skeleton.get_bone_pose_rotation(bone)]
	play_state("idle")
	player.advance(0)
func play_state(next: String, speed := 1.0) -> void:
	var clip: String=CLIPS[next]
	if next!=state:
		state=next; state_time=0
		player.play(clip,0.18)
	player.speed_scale=speed

func reset_pose() -> void:
	player.stop(); locomotion_player.stop(); last_arm_rotations.clear(); crouch_weight=0
	state=""; hit_left=0; action_left=0; previous_attack=0; previous_recoil=0; death_done=false
	play_state("idle"); player.advance(0)
func hit() -> void:
	hit_left=player.get_animation("Hit_React").length
func die() -> void:
	death_start_pose.clear()
	for bone in range(skeleton.get_bone_count()): death_start_pose[bone]=[skeleton.get_bone_pose_position(bone),skeleton.get_bone_pose_rotation(bone)]
	play_state("death"); player.advance(0); death_done=false
func head_position() -> Vector3:
	var point := skeleton.get_bone_global_pose(head_bone).origin+Vector3(0,0.035,0)
	return owner_animator.get_parent().global_transform.affine_inverse() * (skeleton.global_transform * point)
func tick(delta: float, speed: float, crouching: bool, weapon: WeaponController, dead: bool, aiming: bool = true) -> void:
	_floor_contact(delta)
	if dead:
		if state!="death": die()
		player.advance(delta); state_time+=delta
		var weight := smoothstep(0,0.3,state_time)
		for bone in death_start_pose:
			skeleton.set_bone_pose_position(bone,death_start_pose[bone][0].lerp(skeleton.get_bone_pose_position(bone),weight))
			skeleton.set_bone_pose_rotation(bone,death_start_pose[bone][1].slerp(skeleton.get_bone_pose_rotation(bone),weight))
		death_done=state_time>=player.get_animation("Death").length
		attach_weapon(weapon)
		return
	if weapon.recoil>previous_recoil+0.15: action_kind="fire"; action_left=0.32; play_state("fire",player.get_animation("Musket_Fire").length/0.32); player.seek(0,true)
	if weapon.animation>previous_attack+0.1: action_kind="katana_attack"; action_left=Katana.COOLDOWN; play_state("katana_attack",player.get_animation("Katana_Slash").length/Katana.COOLDOWN); player.seek(0,true)
	previous_recoil=weapon.recoil; previous_attack=weapon.animation
	hit_left=maxf(0,hit_left-delta); action_left=maxf(0,action_left-delta)
	var next := "idle"; var playback := 1.0
	if hit_left>0: next="hit"
	elif action_left>0: next=action_kind; playback=player.get_animation(CLIPS[next]).length/(0.32 if next=="fire" else Katana.COOLDOWN)
	elif weapon.selected==0 and weapon.musket.remaining>0:
		next="reload"; playback=player.get_animation("Musket_Reload").length/Musket.RELOAD_TIME
	elif speed>0.1:
		next="sprint" if speed>=3 else "walk"
		playback=clampf(speed/(2.085 if next=="sprint" else 0.839),0.45,3.5)
	elif weapon.selected==0: next="aim" if aiming else "idle"
	else: next="katana_ready"
	# Keep locomotion on the lower body during reload, hit and attack clips.
	# Sampling is manual: there is exactly one ammunition/physics clock.
	var lower_pose: Dictionary={}
	if speed>0.1:
		var locomotion := "Run" if speed>=3 else "Walk"
		if locomotion_player.current_animation!=locomotion: locomotion_player.play(locomotion,0.18)
		locomotion_player.speed_scale=clampf(speed/(2.085 if speed>=3 else 0.839),0.45,3.5)
		locomotion_player.advance(delta)
		for bone in range(skeleton.get_bone_count()):
			if _lower_body(bone): lower_pose[bone]=[skeleton.get_bone_pose_position(bone),skeleton.get_bone_pose_rotation(bone),skeleton.get_bone_pose_scale(bone)]
	play_state(next,playback)
	# A reload resumed after another action seeks to the actual ammunition timer.
	if next=="reload": player.seek((1-weapon.musket.remaining/Musket.RELOAD_TIME)*player.get_animation("Musket_Reload").length,true)
	player.advance(delta); state_time+=delta
	for bone in lower_pose:
		skeleton.set_bone_pose_position(bone,lower_pose[bone][0]); skeleton.set_bone_pose_rotation(bone,lower_pose[bone][1]); skeleton.set_bone_pose_scale(bone,lower_pose[bone][2])
	crouch_weight=lerpf(crouch_weight,1.0 if crouching else 0.0,1-exp(-12*delta))
	# Additive compatible crouch; no rest-bone or skin-bind transforms are changed.
	for name in ["thigh_l","thigh_r"]: bend(name,Vector3.RIGHT,-0.95*crouch_weight)
	for name in ["calf_l","calf_r"]: bend(name,Vector3.RIGHT,1.9*crouch_weight)
	for name in ["foot_l","foot_r"]: bend(name,Vector3.RIGHT,-0.95*crouch_weight)
	if crouch_weight>0.01:
		var foot_y := minf(skeleton.get_bone_global_pose(skeleton.find_bone("foot_l")).origin.y,skeleton.get_bone_global_pose(skeleton.find_bone("foot_r")).origin.y)
		owner_animator.position.y+=clampf(0.076-(foot_y+owner_animator.position.y),-0.15,0.3)*crouch_weight
	# Musket arm stance while moving: preserve the clip's lower-body locomotion.
	var overlay: Dictionary={}
	if next in ["walk","sprint"]: overlay=aim_pose if weapon.selected==0 else ready_pose
	elif next=="katana_ready": overlay=ready_pose
	elif next=="idle" and weapon.selected==0: overlay=aim_pose
	for bone in aim_pose:
		var rotation: Quaternion=overlay[bone][1] if overlay.has(bone) else skeleton.get_bone_pose_rotation(bone)
		if last_arm_rotations.has(bone): rotation=last_arm_rotations[bone].slerp(rotation,1-exp(-18*delta))
		skeleton.set_bone_pose_rotation(bone,rotation); last_arm_rotations[bone]=rotation
		if overlay.has(bone): skeleton.set_bone_pose_position(bone,overlay[bone][0])
	if weapon.selected==0 and state in ["idle","aim","fire","walk","sprint"]: _align_aim_axis()
	attach_weapon(weapon)
func _upper_body(bone: int) -> bool:
	var index := bone
	while index>=0:
		if index in [arm_left,arm_right]: return true
		index=skeleton.get_bone_parent(index)
	return false
func bend(name: String, axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(name)
	skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index)*Quaternion(axis,angle))
func attach_weapon(weapon: WeaponController) -> void:
	var selected := weapon.selected
	if weapon.actor is BotController:
		weapon.gun_model.transform=Transform3D.IDENTITY
		weapon.sword_model.transform=Transform3D.IDENTITY
	# Rigid attachment derived from the animated palm positions. The source gun's
	# firing grip is +X .35 m; Geometry.weapon maps its forward axis to local -Z.
	var rig_transform := owner_animator.global_transform.affine_inverse()*skeleton.global_transform
	var right := rig_transform*_palm(right_bone)
	var left := rig_transform*_palm(left_bone)
	var forward := (left-right).normalized() if selected==0 else -(rig_transform*skeleton.get_bone_global_pose(right_bone).basis.y).normalized()
	if selected==0 and state!="reload": forward.y=0; forward=forward.normalized()
	if forward.length()<0.1: forward=Vector3.FORWARD
	var up := Vector3.UP
	if absf(forward.dot(up))>0.95: up=Vector3.RIGHT
	var orientation := Basis.looking_at(forward,up)
	var grip_offset := Vector3(0,0.075,-0.35) if selected==0 else Vector3(0,0.015,0.15)
	owner_animator.weapon_socket.transform=Transform3D(orientation,right-orientation*grip_offset)
	lower_hand_error=left.distance_to(right+forward*0.4)

func _lower_body(bone: int) -> bool:
	var index := bone
	while index>=0:
		if skeleton.get_bone_name(index)=="spine_01": return false
		index=skeleton.get_bone_parent(index)
	return true

func _align_aim_axis() -> void:
	var right := _palm(right_bone)
	var left := _palm(left_bone)
	var direction := left-right; direction.y=0
	if direction.length()<0.01: return
	var yaw := atan2(direction.x,direction.z)
	_rotate_global(skeleton.find_bone("spine_01"),Basis(Vector3.UP,-yaw))
	_rotate_global(skeleton.find_bone("neck_01"),Basis(Vector3.UP,yaw))
func _rotate_global(index: int, adjustment: Basis) -> void:
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var local := parent_basis.inverse()*adjustment*skeleton.get_bone_global_pose(index).basis
	skeleton.set_bone_pose_rotation(index,local.get_rotation_quaternion())

func _palm(index: int) -> Vector3:
	var pose := skeleton.get_bone_global_pose(index)
	return pose.origin+pose.basis.y*0.055

func _floor_contact(delta: float) -> void:
	# Palace hard-floor render surfaces sit slightly above the flat physics floor.
	# Offset only the visual instance; movement and collision geometry stay intact.
	var actor := owner_animator.get_parent()
	var game := actor.get_parent() if actor!=null else null
	if game!=null and game.has_method("start_match"):
		var surface: String=game.arena.surface_at(owner_animator.global_position)
		var offset := 0.05 if surface=="wood" else (0.035 if surface=="stone" else 0.0)
		visual.position.y=lerpf(visual.position.y,offset,1-exp(-20*delta))
