class_name BotController
extends CharacterBody3D
@export var character_asset: PackedScene
var game: Node3D
var team := 0
var health: HealthComponent
var weapons: WeaponController
var visual: CharacterAnimator
var crouching := false
var head_hitbox: Area3D
var body_shape: CollisionShape3D
var target: Node3D
var dead_time := 0.0
var think := 0.0
var path := PackedVector3Array()
var waypoint := 0
var fire_delay := 0.0
var travel := 0.0
var tactical_goal := Vector3.ZERO
var cover_goal := Vector3.ZERO
var cover_time := 0.0
var route_variant := 0
var interior_visits := 0
var cover_selections := 0
var reposition_time := 0.0
func setup(g: Node3D, faction: int) -> void:
	game=g; team=faction
	route_variant=get_instance_id()%3
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.34; capsule.height=1.45
	body_shape=col
	col.shape=capsule; col.position.y=0.725; add_child(col)
	health=HealthComponent.new(); add_child(health); health.died.connect(_die)
	head_hitbox=DamageSystem.add_head_hitbox(self)
	if team==1 and character_asset==null: character_asset=preload("res://assets/characters/Ronin.glb")
	visual=Geometry.warrior(self,team,character_asset)
	weapons=WeaponController.new(); visual.weapon_socket.add_child(weapons)
	weapons.position=Vector3.ZERO; weapons.setup(self)
	fire_delay=randf_range(0.5,2.2)
func _physics_process(delta: float) -> void:
	if game.paused: return
	health.tick(delta)
	if health.value<=0:
		visual.tick(delta,0,false,weapons)
		dead_time-=delta
		if game.match_state.active and dead_time<=0 and visual.death_finished: respawn()
		return
	if not game.match_state.active: return
	weapons.tick(delta)
	visual.tick(delta,Vector2(velocity.x,velocity.z).length(),crouching,weapons,is_instance_valid(target) and target.health.value>0)
	head_hitbox.position=visual.head_position()
	body_shape.shape.height=1.45+visual.position.y
	body_shape.position.y=body_shape.shape.height/2
	think-=delta; fire_delay-=delta; cover_time=maxf(0,cover_time-delta)
	if game.arena.districts.palace.has_point(Vector2(global_position.x,global_position.z)): interior_visits+=1
	if think<=0:
		think=randf_range(0.4,0.8)
		_acquire()
		if is_instance_valid(target):
			var target_pos: Vector3=target.global_position
			if global_position.distance_to(target_pos)>45:
				target_pos=Vector3([-18,0,18][route_variant],0,12 if team==0 else -12)
			if weapons.musket.remaining>0 and global_position.distance_to(target.global_position)>5:
				if cover_time<=0:
					cover_goal=game.arena.reload_cover(global_position,target.global_position); cover_time=4.5
					if cover_goal.distance_to(global_position)>0.5: cover_selections+=1
				target_pos=cover_goal
			elif game.arena.protected_zone(target_pos,1-team):
				target_pos=Vector3(0,0,24 if team==0 else -24)
			tactical_goal=target_pos
			path=game.arena.route(global_position,tactical_goal)
			waypoint=1 if path.size()>1 else 0
		if not is_instance_valid(target):
			path=game.arena.route(global_position,Vector3([-18,0,18][route_variant],0,12 if team==0 else -12)); waypoint=1 if path.size()>1 else 0
	if not is_instance_valid(target) or target.health.value<=0:
		_patrol(delta)
		return
	var offset: Vector3 = target.global_position-global_position
	var distance := offset.length()
	if offset.length_squared()>0.01: rotation.y=lerp_angle(rotation.y,atan2(-offset.x,-offset.z),1-exp(-10*delta))
	var origin := global_position+Vector3(0,1.4,0)
	var direction: Vector3 = (target.global_position+Vector3(0,1.15,0)-origin).normalized()
	var hit := DamageSystem.trace(self,origin,direction,50)
	var clear: bool = not hit.is_empty() and hit.collider==target
	var desired := 1 if distance<3.2 else 0
	if desired!=weapons.selected: weapons.switch_weapon()
	if not weapons.musket.loaded: weapons.reload()
	if clear and fire_delay<=0 and ((weapons.selected==0 and distance<28) or distance<2.5):
		# Small spread makes missed shots possible; reload continues in background.
		var spread := Vector3(randf_range(-0.025,0.025),randf_range(-0.018,0.018),0) if weapons.selected==0 else Vector3.ZERO
		weapons.attack(origin,(direction+spread).normalized())
		fire_delay=randf_range(0.9,1.5)
	var movement := Vector3.ZERO
	if distance>1.9 and (not clear or weapons.selected==1 or distance>20 or weapons.musket.remaining>0):
		if waypoint<path.size():
			movement=path[waypoint]-global_position
			movement.y=0
			if movement.length()<0.65: waypoint+=1
		elif clear: movement=offset
	movement.y=0
	movement=_separate(movement.normalized())
	velocity.x=movement.x*3.2; velocity.z=movement.z*3.2
	velocity.y-=20*delta
	move_and_slide()
	travel+=delta*movement.length()*8
	crouching=clear and distance>8 and movement.length()<0.1
	if global_position.y < -5: health.damage(100,self)
func _acquire() -> void:
	var nearest := INF
	target=null
	for actor in game.actors:
		if not is_instance_valid(actor) or actor.team==team or actor.health.value<=0 or actor.health.protection>0 or game.arena.protected_zone(actor.global_position,1-team): continue
		var d := global_position.distance_squared_to(actor.global_position)
		if d<nearest: nearest=d; target=actor
func _die(attacker: Node) -> void:
	game.record_kill(attacker,self)
	dead_time=3
	velocity=Vector3.ZERO
	visual.die()
	head_hitbox.collision_layer=0
	collision_layer=0
	collision_mask=1
	game.sounds.play_sound("death",global_position)
func respawn() -> void:
	global_position=game.spawns.location(team,game.actors)
	velocity=Vector3.ZERO
	health.reset(); health.protection=3.0; weapons.musket=Musket.new()
	weapons.recoil=0; weapons.animation=0; weapons.switch_time=0
	weapons.shown_weapon=weapons.selected
	weapons.gun_model.visible=weapons.selected==0; weapons.sword_model.visible=weapons.selected==1
	visual.visible=true; collision_layer=1
	visual.reset_pose(); crouching=false; head_hitbox.collision_layer=2
	think=0; fire_delay=1

func react_to_hit() -> void:
	visual.react()
func head_height() -> float:
	return visual.head_position().y

func _patrol(delta: float) -> void:
	var direction := Vector3.ZERO
	if waypoint<path.size():
		direction=path[waypoint]-global_position; direction.y=0
		if direction.length()<0.65: waypoint+=1
	direction=_separate(direction.normalized())
	velocity.x=direction.x*3.2; velocity.z=direction.z*3.2
	velocity.y-=20*delta
	move_and_slide()
	if direction.length()>0.1: rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*8)

func _separate(direction: Vector3) -> Vector3:
	if direction.length()<0.1: return direction
	var steering := Vector3.ZERO
	for actor in game.actors:
		if actor==self or not is_instance_valid(actor) or actor.health.value<=0: continue
		var offset: Vector3=global_position-actor.global_position; offset.y=0
		var d := offset.length()
		if d>0.01 and d<1.2: steering+=offset.normalized()*(1.2-d)
	return (direction+steering*1.2).normalized()
