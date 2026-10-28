class_name Arena
extends Node3D
const EXTENT := 73
var navigation := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var cover_points: Array[Vector3] = []
var region: NavigationRegion3D
var districts := {"palace":Rect2(-22,-16,44,32),"courtyard":Rect2(-36,19,72,34),"west_garden":Rect2(-68,-58,34,85),"east_garden":Rect2(34,-27,34,85)}
func _ready() -> void:
	name="PalaceOfAsh"
	region=NavigationRegion3D.new(); add_child(region)
	region.add_child(preload("res://assets/palace/Palace.glb").instantiate())
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/palace/layout.json"))
	for item in layout.colliders:
		var p := Vector3(item.p[0],item.p[1],item.p[2]); var s := Vector3(item.s[0],item.s[1],item.s[2])
		var body := StaticBody3D.new(); region.add_child(body); body.position=p
		var col := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=s; col.shape=shape; body.add_child(col)
		if p.y>0 and p.y+s.y/2>0.1: obstacles.append(Rect2(Vector2(p.x-s.x/2,p.z-s.z/2),Vector2(s.x,s.z)))
	for p in layout.cover: cover_points.append(Vector3(p[0],0,p[2]))
	navigation.region=Rect2i(-EXTENT,-EXTENT,EXTENT*2+1,EXTENT*2+1)
	navigation.cell_size=Vector2.ONE
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for rect in obstacles:
		var r := rect.grow(0.5)
		for x in range(maxi(-EXTENT,floori(r.position.x)),mini(EXTENT,ceili(r.end.x))+1):
			for z in range(maxi(-EXTENT,floori(r.position.y)),mini(EXTENT,ceili(r.end.y))+1):
				if r.has_point(Vector2(x,z)): navigation.set_point_solid(Vector2i(x,z))
	# Bake a matching engine navmesh from the collision floor/walls, not decorative roofs.
	var mesh := NavigationMesh.new(); mesh.agent_radius=0.5; mesh.agent_height=2.0
	mesh.cell_size=0.25; mesh.cell_height=0.25
	mesh.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh=mesh
	region.bake_navigation_mesh(false)
	for z in [-8,8]:
		var lamp := OmniLight3D.new(); add_child(lamp); lamp.position=Vector3(0,3.1,z)
		lamp.light_color=Color("ffd4a0"); lamp.light_energy=1.6; lamp.omni_range=14
func nearest_cell(p: Vector3) -> Vector2i:
	var a := Vector2i(clampi(roundi(p.x),-EXTENT,EXTENT),clampi(roundi(p.z),-EXTENT,EXTENT))
	if not navigation.is_point_solid(a): return a
	for radius in range(1,5):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var b := a+Vector2i(x,z)
				if navigation.is_in_boundsv(b) and not navigation.is_point_solid(b): return b
	return a
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_cell(from); var b := nearest_cell(to)
	var result := PackedVector3Array()
	if navigation.is_point_solid(a) or navigation.is_point_solid(b): return result
	for point in navigation.get_id_path(a,b): result.append(Vector3(point.x,0.04,point.y))
	return result
func protected_zone(pos: Vector3, team: int) -> bool:
	return Vector2(pos.x-(-57 if team==0 else 57),pos.z-(40 if team==0 else -40)).length()<13
func reload_cover(from: Vector3, enemy: Vector3) -> Vector3:
	var best := from; var score := INF
	for point in cover_points:
		var distance := from.distance_to(point)
		if distance>24: continue
		var query := PhysicsRayQueryParameters3D.create(point+Vector3(0,1,0),enemy+Vector3(0,1.2,0),1)
		var blocked := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		var value := distance+(0 if blocked else 35)
		if value<score and not route(from,point).is_empty(): score=value; best=point
	return best
func surface_at(p: Vector3) -> String:
	if Rect2(-64,33,14,14).has_point(Vector2(p.x,p.z)) or Rect2(50,-47,14,14).has_point(Vector2(p.x,p.z)) or Rect2(-50,-31,14,18).has_point(Vector2(p.x,p.z)) or Rect2(36,13,14,18).has_point(Vector2(p.x,p.z)) or districts.palace.has_point(Vector2(p.x,p.z)) or (absf(absf(p.x)-29)<2.5 and absf(p.z)<36): return "wood"
	if districts.courtyard.has_point(Vector2(p.x,p.z)) or absf(absf(p.x)-40)<3 or absf(absf(p.z)-52)<7: return "stone"
	return "soil"
