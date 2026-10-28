class_name PlayerController
extends CharacterBody3D
@export var character_asset: PackedScene
var game: Node3D
var team := 0
var health: HealthComponent
var weapons: WeaponController
var camera: Camera3D
var dead_time := 0.0
var sensitivity := 0.002
var footsteps := 0.0
var visual: CharacterAnimator
var external_gun: Node3D
var external_sword: Node3D
var auto_sprint := false
var crouching := false
var crouch_blend := 0.0
var body_shape: CollisionShape3D
var head_hitbox: Area3D
var death_body: CharacterAnimator
var damage_kick := 0.0
func setup(g: Node3D, faction: int) -> void:
	game=g; team=faction
	name="PlayerController"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.32; capsule.height=1.45
	shape.shape=capsule; shape.position.y=0.725
	add_child(shape); body_shape=shape
	head_hitbox=DamageSystem.add_head_hitbox(self)
	health=HealthComponent.new(); add_child(health)
	health.died.connect(_die)
	health.changed.connect(func(v):
		if v<100: game.hud.hurt=0.25)
	camera=Camera3D.new(); add_child(camera)
	camera.position.y=1.65; camera.current=true; camera.fov=78
	weapons=WeaponController.new(); camera.add_child(weapons)
	weapons.position=Vector3(0.26,-0.27,-0.35)
	weapons.setup(self)
	if team==1:
		if character_asset==null: character_asset=preload("res://assets/characters/Ronin.glb")
		visual=Geometry.warrior(self,team,character_asset)
		external_gun=Geometry.weapon(visual.weapon_socket,false); external_sword=Geometry.weapon(visual.weapon_socket,true)
		# Own body is on a dedicated render layer. Other/default cameras still see it.
		for part in visual.find_children("*","VisualInstance3D",true,false): part.layers=2
		camera.cull_mask=camera.cull_mask & ~2
func _unhandled_input(event: InputEvent) -> void:
	if not game.match_state.active or health.value<=0: return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x*sensitivity)
		camera.rotation.x=clampf(camera.rotation.x-event.relative.y*sensitivity,-1.35,1.35)
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	if event.is_action_pressed("fire"): weapons.attack(camera.global_position,-camera.global_basis.z)
	if event.is_action_pressed("auto_sprint"): auto_sprint=not auto_sprint
	if event.is_action_pressed("reload"): weapons.reload()
	if event.is_action_pressed("switch"): weapons.switch_weapon()
func _physics_process(delta: float) -> void:
	if game.paused: return
	health.tick(delta)
	if health.value<=0:
		if is_instance_valid(death_body): death_body.tick(delta,0,false,weapons)
		camera.rotation.z=lerpf(camera.rotation.z,0.16,1-exp(-5*delta))
		dead_time-=delta
		if game.match_state.active and dead_time<=0 and (not is_instance_valid(death_body) or death_body.death_finished): respawn()
		return
	if not game.match_state.active: return
	weapons.tick(delta)
	if is_instance_valid(visual):
		visual.tick(delta,Vector2(velocity.x,velocity.z).length(),crouching,weapons,Input.is_action_pressed("aim"))
		external_gun.visible=weapons.gun_model.visible; external_sword.visible=weapons.sword_model.visible
		external_gun.transform=Transform3D.IDENTITY; external_sword.transform=Transform3D.IDENTITY
	var input := Input.get_vector("left","right","forward","back") if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
	var direction := transform.basis * Vector3(input.x,0,input.y)
	crouching=Input.is_action_pressed("crouch")
	# A standing capsule overlap prevents standing into overhead geometry.
	if not crouching and crouch_blend>0.1:
		var probe := PhysicsShapeQueryParameters3D.new()
		var stand := CapsuleShape3D.new(); stand.radius=0.32; stand.height=1.45
		probe.shape=stand; probe.transform=Transform3D(Basis.IDENTITY,global_position+Vector3(0,0.725,0)); probe.exclude=[get_rid()]; probe.collision_mask=1
		crouching=not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty()
	crouch_blend=lerpf(crouch_blend,1.0 if crouching else 0.0,1-exp(-12*delta))
	body_shape.shape.height=1.45-crouch_blend*0.43
	body_shape.position.y=body_shape.shape.height/2
	head_hitbox.position=visual.head_position() if is_instance_valid(visual) else Vector3(0,head_height(),0)
	camera.position.y=1.65-crouch_blend*0.43
	var speed := 2.2 if crouching else (7.0 if (Input.is_action_pressed("sprint") or auto_sprint) else 4.5)
	velocity.x=direction.x*speed; velocity.z=direction.z*speed
	if not is_on_floor(): velocity.y-=20*delta
	elif Input.is_action_just_pressed("jump"): velocity.y=7
	move_and_slide()
	if global_position.y < -5: health.damage(100,self)
	var aiming := Input.is_action_pressed("aim") and weapons.selected==0
	camera.fov=lerpf(camera.fov,55.0 if aiming else 78.0,delta*10)
	damage_kick=move_toward(damage_kick,0,delta*2)
	camera.rotation.z=lerpf(camera.rotation.z,damage_kick*0.025,delta*12)
	weapons.position.x=lerpf(weapons.position.x,0.03 if aiming else 0.26,delta*10)
	if input.length()>0 and is_on_floor():
		footsteps-=delta
		if footsteps<=0:
			game.sounds.play_sound("step_"+game.arena.surface_at(global_position)); footsteps=0.32 if speed>5 else 0.47
func _die(attacker: Node) -> void:
	dead_time=3
	if is_instance_valid(visual): visual.visible=false
	weapons.visible=false
	velocity=Vector3.ZERO; collision_layer=0; head_hitbox.collision_layer=0
	death_body=Geometry.warrior(game,team,character_asset)
	death_body.global_position=global_position; death_body.rotation.y=rotation.y
	# Body has world-space placement; death animation owns its local fall transform.
	var anchor := Node3D.new(); game.add_child(anchor); anchor.global_position=global_position; anchor.rotation.y=rotation.y
	death_body.reparent(anchor); death_body.transform=Transform3D.IDENTITY
	death_body.die()
	game.record_kill(attacker,self)
	game.sounds.play_sound("death")
func respawn() -> void:
	if is_instance_valid(death_body): death_body.get_parent().queue_free()
	collision_layer=1; head_hitbox.collision_layer=2
	crouching=false; crouch_blend=0
	global_position=game.spawns.location(team,game.actors)
	rotation.y=atan2(global_position.x,global_position.z)
	camera.rotation=Vector3.ZERO
	velocity=Vector3.ZERO
	health.reset(); health.protection=3.0
	weapons.musket=Musket.new()
	weapons.recoil=0; weapons.animation=0; weapons.switch_time=0
	weapons.shown_weapon=weapons.selected
	weapons.gun_model.visible=weapons.selected==0; weapons.sword_model.visible=weapons.selected==1
	weapons.visible=true
	if is_instance_valid(visual): visual.visible=true; visual.reset_pose()

func react_to_hit() -> void:
	damage_kick=1
func head_height() -> float:
	return visual.head_position().y if is_instance_valid(visual) else 1.64-crouch_blend*0.43
func _exit_tree() -> void:
	if is_instance_valid(death_body): death_body.get_parent().queue_free()
