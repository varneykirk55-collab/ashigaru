class_name FirstPersonViewmodel
extends Node
## Camera-space presentation only. Ammunition, damage and action clocks stay in WeaponController.
# Reference points on the ORIGINAL low leaf/blade; no added sight geometry.
const AIM_REAR := Vector3(0,0.128,-0.561)
const AIM_FRONT := Vector3(0,0.124,-1.432)
const ADS_PITCH := 0.00459239
const ADS_HEIGHT := 0.130575
static var arm_meshes: Dictionary = {}
var controller: WeaponController
var rig: Node3D
var skeleton: Skeleton3D
var viewport: SubViewport
var view_camera: Camera3D
var overlay: CanvasLayer
var image: TextureRect
var space: Node3D
var ads := 0.0
var aim_blocked := false
var gait := 0.0
var reload_stage := "ready"
var palm_error := 0.0
var hand_basis: Dictionary = {}
var previous_hands: Dictionary = {}
var flash: MeshInstance3D
var right_target := Vector3.ZERO
var left_target := Vector3.ZERO
func setup(owner_weapon: WeaponController) -> void:
	controller=owner_weapon
	viewport=SubViewport.new(); add_child(viewport)
	viewport.own_world_3d=true; viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	space=Node3D.new(); viewport.add_child(space)
	view_camera=Camera3D.new(); space.add_child(view_camera); view_camera.current=true; view_camera.near=0.025
	var environment := WorldEnvironment.new(); space.add_child(environment)
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c4ccd3"); environment.environment.ambient_light_energy=0.6
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sky := Sky.new(); sky.sky_material=ProceduralSkyMaterial.new(); environment.environment.sky=sky
	environment.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var fill := OmniLight3D.new(); space.add_child(fill); fill.position=Vector3(-0.3,0.3,0.3); fill.omni_range=4; fill.light_energy=0.65
	var light := DirectionalLight3D.new(); space.add_child(light); light.rotation_degrees=Vector3(-38,-35,0); light.light_color=Color("ffdfaa"); light.light_energy=0.95
	controller.gun_model.reparent(space,false); controller.sword_model.reparent(space,false)
	rig=preload("res://assets/characters/Ronin.glb").instantiate(); space.add_child(rig)
	rig.position=Vector3(0,-1.82,-0.16); rig.rotation.y=PI
	skeleton=rig.find_children("*","Skeleton3D",true,false)[0]
	var animator: AnimationPlayer=rig.find_children("*","AnimationPlayer",true,false)[0]
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.play("Musket_Aim"); animator.seek(0.75,true); animator.advance(0)
	for side in ["l","r"]:
		var bone := skeleton.find_bone("hand_"+side)
		hand_basis[side]=Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT) if side=="r" else Basis(Vector3.FORWARD,Vector3.RIGHT,Vector3.DOWN)
		for finger in ["index","middle","ring","pinky"]:
			for joint in range(1,4):
				var index := skeleton.find_bone("%s_%02d_%s" % [finger,joint,side])
				var rest := skeleton.get_bone_rest(index).basis
				skeleton.set_bone_pose_rotation(index,(rest*Basis(Vector3.RIGHT,-0.75 if joint==1 else -0.95)).get_rotation_quaternion())
	# Retain original vertex attributes, skin binds, materials and textures. Only the
	# triangle index list is filtered; the source GLB and third-person instance are untouched.
	for part: MeshInstance3D in rig.find_children("*","MeshInstance3D",true,false):
		if part.name not in ["Ronin_Body","Ronin_Kimono"]: part.queue_free(); continue
		if not arm_meshes.has(part.name): arm_meshes[part.name]=_extract_arms(part)
		part.mesh=arm_meshes[part.name]; part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.extra_cull_margin=3
	overlay=CanvasLayer.new(); overlay.layer=0; add_child(overlay)
	image=TextureRect.new(); overlay.add_child(image); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.texture=viewport.get_texture(); image.stretch_mode=TextureRect.STRETCH_SCALE
	var mat := StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color=Color("ffd38a"); mat.emission_enabled=true; mat.emission=Color("ffbc62"); mat.emission_energy_multiplier=3
	flash=Geometry.sphere(controller.gun_model,Vector3(0,0.065,-1.49),Vector3(0.07,0.07,0.15),mat); flash.visible=false
	reset_pose()
func _extract_arms(part: MeshInstance3D) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in range(part.mesh.get_surface_count()):
		if part.name=="Ronin_Body" and surface!=0: continue
		var arrays := part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for i in range(0,indices.size(),3):
			var arm := true
			for j in range(3):
				var v := vertices[indices[i+j]]
				if absf(v.x)<0.195 or v.y<1.0: arm=false; break
			if arm: kept.append_array(indices.slice(i,i+3))
		if kept.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX]=kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,part.get_active_material(surface))
	return result
func _process(_delta: float) -> void:
	if not is_instance_valid(controller.actor): return
	var actor: PlayerController=controller.actor
	var show_view: bool= actor.health.value>0 and controller.visible and actor.game.match_state.active and actor.camera.current
	overlay.visible=show_view
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if show_view else SubViewport.UPDATE_DISABLED
	var extent := Vector2i(get_viewport().get_visible_rect().size)
	if viewport.size!=extent: viewport.size=extent
	view_camera.fov=actor.camera.fov
func reset_pose() -> void:
	aim_blocked=Input.is_action_pressed("aim")
	ads=0; gait=0; previous_hands.clear(); reload_stage="ready"
	controller.gun_model.position=Vector3(0.13,-0.27,0.05); controller.gun_model.rotation=Vector3.ZERO
	controller.sword_model.position=Vector3(0.22,-0.08,-0.60); controller.sword_model.rotation=Vector3(0.6,0,-0.2)
	if skeleton!=null: update(0.0)
func update(delta: float) -> void:
	var actor: PlayerController=controller.actor
	if not Input.is_action_pressed("aim"): aim_blocked=false
	var aiming := not aim_blocked and Input.is_action_pressed("aim") and controller.selected==0 and actor.health.value>0 and controller.switch_time<=0 and (controller.musket.remaining<=0 or controller.recoil>0.05)
	ads=lerpf(ads,1.0 if aiming else 0.0,1-exp(-14*delta))
	var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	gait+=delta*(11 if speed>5 else 7)
	var bob := sin(gait)*minf(speed,7)*0.0018*(1-ads*0.95)
	var dip := sin(clampf(controller.switch_time/0.36,0,1)*PI)*0.48
	var pos := Vector3(0.13,-0.27,0.05).lerp(Vector3(0,-ADS_HEIGHT,0.0),ads)
	var rot := Vector3(ADS_PITCH*ads,0,0)
	var loading := controller.musket.remaining>0 and controller.shown_weapon==0
	var progress := 1-controller.musket.remaining/Musket.RELOAD_TIME
	var support := Vector3(-0.055,-0.035,-0.60)
	reload_stage="ready"
	if loading:
		# Smooth keyed choreography in timer space. Switching away never touches this clock.
		var t := clampf(progress,0,1)
		var weight := smoothstep(0.04,0.20,t)*(1-smoothstep(0.82,1.0,t))
		pos+=Vector3(-0.035,-0.08,-0.05)*weight
		rot=Vector3(0.14,0.08,0.65)*weight
		reload_stage="lower" if t<0.2 else ("pouch" if t<0.39 else ("load" if t<0.62 else ("mechanism" if t<0.79 else "return")))
	var recoil := controller.recoil
	pos+=Vector3(0,bob-dip,recoil*0.085)
	rot+=Vector3(recoil*0.045,0,-recoil*0.025)
	controller.gun_model.position=pos; controller.gun_model.rotation=rot
	var attack_t := clampf((0.65-controller.animation)/0.65,0,1)
	var slash := sin(attack_t*PI) if controller.animation>0 else 0.0
	controller.sword_model.position=Vector3(0.22-slash*0.33,-0.08-slash*0.06-dip,-0.60-slash*0.08)
	controller.sword_model.rotation=Vector3(0.6-slash*0.9,-slash*0.75,-0.2+slash*1.1)
	var weapon := controller.gun_model if controller.shown_weapon==0 else controller.sword_model
	var right_grip := Vector3(0.035,-0.015,-0.35) if controller.shown_weapon==0 else Vector3(0.025,-0.025,0.09)
	var left_grip := support if controller.shown_weapon==0 else Vector3(-0.025,-0.005,0.22)
	right_target=weapon.transform*right_grip; left_target=weapon.transform*left_grip
	if loading:
		var t := clampf(progress,0,1)
		var keys := [0.0,0.18,0.34,0.48,0.60,0.71,0.79,0.91,1.0]
		var points := [left_target,left_target,Vector3(-0.24,-0.58,-0.13),weapon.transform*Vector3(-0.06,0.17,-0.74),weapon.transform*Vector3(-0.04,0.04,-0.78),weapon.transform*Vector3(0.07,0.12,-0.39),weapon.transform*Vector3(0.065,0.045,-0.40),left_target,left_target]
		for i in range(keys.size()-1):
			if t>=keys[i] and t<=keys[i+1]: left_target=points[i].lerp(points[i+1],smoothstep(keys[i],keys[i+1],t)); break
	flash.visible=recoil>0.83 and controller.shown_weapon==0
	palm_error=0
	for side in ["r","l"]:
		var basis: Basis=hand_basis[side]
		if controller.shown_weapon==1:
			# Wrist aligned with the two-handed hilt; fingers keep their original articulated rig.
			basis=Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT) if side=="r" else Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT)
		basis=weapon.basis*basis
		var target := right_target if side=="r" else left_target
		var wrist := target-basis.y*0.055
		var pose := Transform3D(basis,wrist)
		if previous_hands.has(side): pose=previous_hands[side].interpolate_with(pose,1-exp(-32*delta))
		previous_hands[side]=pose
		_solve_arm(side,pose)
		_grip_fingers(side,weapon,0.09 if side=="r" else 0.22)
		var bone := skeleton.find_bone("hand_"+side)
		var palm := rig.transform*(skeleton.get_bone_global_pose(bone)*Vector3(0,0.055,0))
		palm_error=maxf(palm_error,palm.distance_to(target))
func _solve_arm(side: String, camera_wrist: Transform3D) -> void:
	var upper := skeleton.find_bone("upperarm_"+side)
	var lower := skeleton.find_bone("lowerarm_"+side)
	var hand := skeleton.find_bone("hand_"+side)
	var goal := rig.transform.affine_inverse()*camera_wrist
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var length_a := skeleton.get_bone_rest(lower).origin.length()
	var length_b := skeleton.get_bone_rest(hand).origin.length()
	var direction := (goal.origin-shoulder).normalized()
	var distance := clampf(shoulder.distance_to(goal.origin),0.03,length_a+length_b-0.001)
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var pole := Vector3(-0.65 if side=="r" else 0.65,-1,-0.1)
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var elbow := shoulder+direction*along+bend*sqrt(maxf(0,length_a*length_a-along*along))
	_point_bone(upper,elbow)
	_point_bone(lower,shoulder+direction*distance)
	var parent := skeleton.get_bone_parent(hand)
	var local := skeleton.get_bone_global_pose(parent).basis.inverse()*goal.basis
	skeleton.set_bone_pose_rotation(hand,local.orthonormalized().get_rotation_quaternion())
func _point_bone(index: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(index)
	var rotation := Quaternion(pose.basis.y.normalized(),(target-pose.origin).normalized())
	var parent := skeleton.get_bone_parent(index)
	var local := skeleton.get_bone_global_pose(parent).basis.inverse()*Basis(rotation)*pose.basis
	skeleton.set_bone_pose_rotation(index,local.orthonormalized().get_rotation_quaternion())

func _grip_fingers(side: String, weapon: Node3D, hilt_z: float) -> void:
	var inv := rig.transform.affine_inverse()
	var sword := controller.shown_weapon==1
	var local_axis := Vector3(0,-0.179,-0.984) if sword else Vector3.FORWARD
	var axis := (inv.basis*weapon.basis*local_axis).normalized()
	var grip_center := Vector3(0,hilt_z*0.182+0.015,hilt_z) if sword else Vector3(0,0,-0.35 if side=="r" else -0.60)
	var center := inv*(weapon.transform*grip_center)
	var radius := 0.022 if sword else 0.038
	for finger in ["index","middle","ring","pinky","thumb"]:
		var first := skeleton.find_bone(finger+"_01_"+side)
		var start := skeleton.get_bone_global_pose(first)
		var on_axis := center+axis*(start.origin-center).dot(axis)
		var radial := (start.origin-on_axis).normalized()
		var tangent := axis.cross(radial)
		var sign_value := 1.0 if tangent.dot(start.basis.y)>=0 else -1.0
		for joint in range(1,4):
			var bone := skeleton.find_bone("%s_%02d_%s" % [finger,joint,side])
			var around := Basis(axis,sign_value*(0.55+0.60*(joint-1)))*radial
			_point_bone(bone,on_axis+around*radius)
