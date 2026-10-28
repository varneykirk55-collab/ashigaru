class_name DamageSystem
extends RefCounted
static func hit(target: Node, amount: float, attacker: Node) -> bool:
	if not is_instance_valid(target) or not target is CharacterBody3D: return false
	if target.team == attacker.team or target.health.value <= 0: return false
	target.health.damage(amount, attacker)
	return true
static func trace(actor: Node3D, origin: Vector3, direction: Vector3, distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance)
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query)
