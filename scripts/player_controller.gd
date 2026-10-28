class_name PlayerController
extends CharacterBody3D
var game: Node3D
var team := 0
var health: HealthComponent
var weapons: WeaponController
var camera: Camera3D
var dead_time := 0.0
var sensitivity := 0.002
var footsteps := 0.0
func setup(g: Node3D, faction: int) -> void:
	game=g; team=faction
	name="PlayerController"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.32; capsule.height=1.8
	shape.shape=capsule; shape.position.y=0.9
	add_child(shape)
	health=HealthComponent.new(); add_child(health)
	health.died.connect(_die)
	health.changed.connect(func(_v): game.hud.hurt=0.35)
	camera=Camera3D.new(); add_child(camera)
	camera.position.y=1.65; camera.current=true; camera.fov=78
	weapons=WeaponController.new(); camera.add_child(weapons)
	weapons.position=Vector3(0.26,-0.27,-0.35)
	weapons.setup(self)
func _unhandled_input(event: InputEvent) -> void:
	if not game.match_state.active or health.value<=0: return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x*sensitivity)
		camera.rotation.x=clampf(camera.rotation.x-event.relative.y*sensitivity,-1.35,1.35)
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
	if event.is_action_pressed("fire"): weapons.attack(camera.global_position,-camera.global_basis.z)
	if event.is_action_pressed("reload"): weapons.reload()
	if event.is_action_pressed("switch"): weapons.switch_weapon()
func _physics_process(delta: float) -> void:
	if not game.match_state.active or game.paused: return
	weapons.tick(delta)
	if health.value<=0:
		dead_time-=delta
		if dead_time<=0: respawn()
		return
	var input := Input.get_vector("left","right","forward","back") if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
	var direction := transform.basis * Vector3(input.x,0,input.y)
	var speed := 7.0 if Input.is_action_pressed("sprint") else 4.5
	velocity.x=direction.x*speed; velocity.z=direction.z*speed
	if not is_on_floor(): velocity.y-=20*delta
	elif Input.is_action_just_pressed("jump"): velocity.y=7
	move_and_slide()
	if global_position.y < -5: health.damage(100,self)
	var aiming := Input.is_action_pressed("aim") and weapons.selected==0
	camera.fov=lerpf(camera.fov,55.0 if aiming else 78.0,delta*10)
	weapons.position.x=lerpf(weapons.position.x,0.03 if aiming else 0.26,delta*10)
	if input.length()>0 and is_on_floor():
		footsteps-=delta
		if footsteps<=0:
			game.sounds.play_sound("step"); footsteps=0.32 if speed>5 else 0.47
func _die(attacker: Node) -> void:
	dead_time=3
	weapons.visible=false
	game.record_kill(attacker,self)
	game.sounds.play_sound("death")
func respawn() -> void:
	global_position=game.spawns.location(team)
	rotation.y=0 if team==0 else PI
	camera.rotation=Vector3.ZERO
	velocity=Vector3.ZERO
	health.reset()
	weapons.musket=Musket.new()
	weapons.visible=true
