class_name BotController
extends CharacterBody3D
var game: Node3D
var team := 0
var health: HealthComponent
var weapons: WeaponController
var visual: Node3D
var target: Node3D
var dead_time := 0.0
var think := 0.0
var path := PackedVector3Array()
var waypoint := 0
var fire_delay := 0.0
var travel := 0.0
func setup(g: Node3D, faction: int) -> void:
	game=g; team=faction
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.34; capsule.height=1.85
	col.shape=capsule; col.position.y=0.93; add_child(col)
	health=HealthComponent.new(); add_child(health); health.died.connect(_die)
	visual=Geometry.warrior(self,team)
	weapons=WeaponController.new(); visual.add_child(weapons)
	weapons.position=Vector3(0.28,1.23,-0.22); weapons.setup(self)
	fire_delay=randf_range(0.5,2.2)
func _physics_process(delta: float) -> void:
	if not game.match_state.active or game.paused: return
	if health.value<=0:
		dead_time-=delta
		if dead_time<=0: respawn()
		return
	weapons.tick(delta)
	think-=delta; fire_delay-=delta
	if think<=0:
		think=randf_range(0.4,0.8)
		_acquire()
		if is_instance_valid(target):
			path=game.arena.route(global_position,target.global_position)
			waypoint=1 if path.size()>1 else 0
	if not is_instance_valid(target) or target.health.value<=0: return
	var offset: Vector3 = target.global_position-global_position
	var distance := offset.length()
	if offset.length_squared()>0.01: rotation.y=atan2(-offset.x,-offset.z)
	var origin := global_position+Vector3(0,1.4,0)
	var direction: Vector3 = (target.global_position+Vector3(0,1.15,0)-origin).normalized()
	var hit := DamageSystem.trace(self,origin,direction,50)
	var clear: bool = not hit.is_empty() and hit.collider==target
	var desired := 1 if distance<3.2 or not weapons.musket.loaded else 0
	if desired!=weapons.selected: weapons.switch_weapon()
	if not weapons.musket.loaded: weapons.reload()
	if clear and fire_delay<=0 and ((weapons.selected==0 and distance<28) or distance<2.5):
		# Small spread makes missed shots possible; reload remains ten seconds.
		var spread := Vector3(randf_range(-0.025,0.025),randf_range(-0.018,0.018),0) if weapons.selected==0 else Vector3.ZERO
		weapons.attack(origin,(direction+spread).normalized())
		fire_delay=randf_range(0.9,1.5)
	var movement := Vector3.ZERO
	if distance>1.9 and (not clear or weapons.selected==1 or distance>20):
		if waypoint<path.size():
			movement=path[waypoint]-global_position
			movement.y=0
			if movement.length()<0.65: waypoint+=1
		elif clear: movement=offset
	movement.y=0
	movement=movement.normalized()
	velocity.x=movement.x*3.2; velocity.z=movement.z*3.2
	velocity.y-=20*delta
	move_and_slide()
	travel+=delta*movement.length()*8
	visual.rotation.z=sin(travel)*0.025
	if global_position.y < -5: health.damage(100,self)
func _acquire() -> void:
	var nearest := INF
	target=null
	for actor in game.actors:
		if not is_instance_valid(actor) or actor.team==team or actor.health.value<=0: continue
		var d := global_position.distance_squared_to(actor.global_position)
		if d<nearest: nearest=d; target=actor
func _die(attacker: Node) -> void:
	game.record_kill(attacker,self)
	dead_time=3
	visual.visible=false
	collision_layer=0
	collision_mask=1
	game.sounds.play_sound("death",global_position)
func respawn() -> void:
	global_position=game.spawns.location(team)
	velocity=Vector3.ZERO
	health.reset(); weapons.musket=Musket.new()
	visual.visible=true; collision_layer=1
	think=0; fire_delay=1
