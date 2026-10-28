class_name DamageSystem
extends RefCounted
static func hit(target: Node, amount: float, attacker: Node) -> bool:
	if not is_instance_valid(target) or not target is CharacterBody3D: return false
	if target.team == attacker.team or target.health.value <= 0: return false
	if target.has_method("react_to_hit"): target.react_to_hit()
	target.health.damage(amount, attacker)
	return true
static func trace(actor: Node3D, origin: Vector3, direction: Vector3, distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance)
	query.exclude = [actor.get_rid(),actor.head_hitbox.get_rid()]
	query.collision_mask=3; query.collide_with_areas=true
	var result := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider is Area3D and result.collider.has_meta("head_owner"):
		result["collider"]=result.collider.get_meta("head_owner")
		result["headshot"]=true
	return result

static func add_head_hitbox(actor: CharacterBody3D) -> Area3D:
	var area := Area3D.new(); actor.add_child(area)
	area.name="HeadHitbox"; area.collision_layer=2; area.collision_mask=0
	area.position.y=1.64; area.set_meta("head_owner",actor)
	var col := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius=0.18
	col.shape=sphere; area.add_child(col)
	return area
