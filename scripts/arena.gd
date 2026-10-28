class_name Arena
extends Node3D
var navigation := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var stone := Geometry.mat(Color("696b65"))
var wood := Geometry.mat(Color("3a2923"))
var plaster := Geometry.mat(Color("c0b69d"))
var tile := Geometry.mat(Color("303b40"),0.2)
var red := Geometry.mat(Color("79382c"))
func _ready() -> void:
	name="CourtyardOfAsh"
	var ground := Geometry.mat(Color("777364"))
	Geometry.box(self,Vector3(0,-0.25,0),Vector3(40,0.5,40),ground,true)
	# Individual stone paving with irregular tonal variation.
	for x in range(-9,10):
		for z in range(-9,10):
			if abs(x)<2 or abs(z)<2:
				var c := 0.28+randf()*0.07
				Geometry.box(self,Vector3(x*2,0.012,z*2),Vector3(1.94,0.04,1.94),Geometry.mat(Color(c,c*1.02,c)))
	for s in [-1,1]:
		wall(Vector3(s*20,1.5,0),Vector3(0.5,3,40))
		wall(Vector3(0,1.5,s*20),Vector3(40,3,0.5))
	# Two halls create three routes: central lane and covered outer passages.
	for x in [-9.0,9.0]:
		hall(Vector3(x,0,0))
	for p in [Vector3(-3,0,7),Vector3(4,0,-7),Vector3(-14,0,-8),Vector3(14,0,8)]:
		cover(p)
	for p in [Vector3(-17,0,16),Vector3(17,0,-16),Vector3(-17,0,-15),Vector3(17,0,15)]:
		tree(p)
	for z in [-12.0,12.0]:
		torii(Vector3(0,0,z))
	for x in [-4.0,4.0]:
		for z in [-4.0,4.0]: lantern(Vector3(x,0,z))
	# Outer landscape silhouettes beyond the arena.
	for i in range(18):
		var angle := i*TAU/18
		var p := Vector3(sin(angle)*65,-4,cos(angle)*65)
		var m := Geometry.cylinder(self,p,1,randf_range(12,22),randf_range(18,34),Geometry.mat(Color("3b5055")))
		m.rotation.y=angle
	navigation.region=Rect2i(-19,-19,39,39)
	navigation.cell_size=Vector2.ONE
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(-19,20):
		for z in range(-19,20):
			for rect in obstacles:
				if rect.grow(0.55).has_point(Vector2(x,z)):
					navigation.set_point_solid(Vector2i(x,z))
func wall(pos: Vector3, size: Vector3) -> void:
	Geometry.box(self,pos,size,plaster,true)
	Geometry.box(self,pos+Vector3(0,size.y/2,0),Vector3(size.x+0.25,0.2,size.z+0.25),tile)
	Geometry.box(self,Vector3(pos.x,0.25,pos.z),Vector3(size.x+0.1,0.5,size.z+0.1),stone)
func hall(p: Vector3) -> void:
	Geometry.box(self,p+Vector3(0,0.12,0),Vector3(5,0.24,10),stone,true)
	# Central solid hall; side colonnades are traversable.
	Geometry.box(self,p+Vector3(0,1.5,0),Vector3(3,3,7),plaster,true)
	obstacles.append(Rect2(Vector2(p.x-1.5,-3.5),Vector2(3,7)))
	for side in [-1,1]:
		for z in [-4.2,-1.4,1.4,4.2]:
			Geometry.cylinder(self,p+Vector3(side*2.1,1.6,z),0.13,0.16,3.2,wood)
			Geometry.box(self,p+Vector3(side*1.52,1.6,z*0.7),Vector3(0.07,2.1,0.8),wood)
		var roof := Geometry.box(self,p+Vector3(side*1.6,3.4,0),Vector3(3.6,0.18,11),tile)
		roof.rotation.z=side*-0.28
		for i in range(24):
			var beam := Geometry.cylinder(self,p+Vector3(side*1.6,3.52,-5.2+i*0.45),0.045,0.045,3.6,tile)
			beam.rotation=Vector3(0,0,PI/2-side*0.28)
	Geometry.box(self,p+Vector3(0,3.95,0),Vector3(0.2,0.2,11.4),tile)
func cover(p: Vector3) -> void:
	Geometry.box(self,p+Vector3(0,0.6,0),Vector3(2.8,1.2,1.2),stone,true)
	Geometry.box(self,p+Vector3(0,1.24,0),Vector3(3,0.14,1.4),tile)
	obstacles.append(Rect2(Vector2(p.x-1.4,p.z-0.6),Vector2(2.8,1.2)))
	for x in [-0.9,0.0,0.9]:
		Geometry.box(self,p+Vector3(x,0.65,-0.61),Vector3(0.04,1.0,0.02),wood)
func torii(p: Vector3) -> void:
	for s in [-1,1]:
		Geometry.cylinder(self,p+Vector3(s*2.4,2,0),0.16,0.22,4,red)
		Geometry.cylinder(self,p+Vector3(s*2.4,0.18,0),0.28,0.3,0.36,stone)
	Geometry.box(self,p+Vector3(0,3.3,0),Vector3(6.3,0.22,0.28),red)
	Geometry.box(self,p+Vector3(0,4.0,0),Vector3(7,0.25,0.5),tile)
	for s in [-1,1]:
		var tip := Geometry.box(self,p+Vector3(s*3.7,4.12,0),Vector3(0.7,0.25,0.5),tile)
		tip.rotation.z=s*0.22
func lantern(p: Vector3) -> void:
	Geometry.cylinder(self,p+Vector3(0,0.1,0),0.45,0.55,0.2,stone)
	Geometry.cylinder(self,p+Vector3(0,0.6,0),0.13,0.2,0.9,stone)
	Geometry.box(self,p+Vector3(0,1.25,0),Vector3(0.6,0.5,0.6),stone)
	var glow := Geometry.mat(Color("e4b76c"))
	glow.emission_enabled=true; glow.emission=Color("c98b3f")
	Geometry.box(self,p+Vector3(0,1.27,-0.305),Vector3(0.3,0.25,0.015),glow)
	Geometry.cylinder(self,p+Vector3(0,1.62,0),0.08,0.55,0.25,tile)
func tree(p: Vector3) -> void:
	Geometry.cylinder(self,p+Vector3(0,2,0),0.2,0.45,4,wood)
	for i in range(7):
		var offset := Vector3(randf_range(-1.8,1.8),randf_range(3.2,5.5),randf_range(-1.8,1.8))
		Geometry.sphere(self,p+offset,Vector3(3.8,1.7,3.5),Geometry.mat(Color("635c4a") if i%3==0 else Color("405247")))
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := Vector2i(clampi(roundi(from.x),-19,19),clampi(roundi(from.z),-19,19))
	var b := Vector2i(clampi(roundi(to.x),-19,19),clampi(roundi(to.z),-19,19))
	var result := PackedVector3Array()
	if navigation.is_point_solid(a) or navigation.is_point_solid(b): return result
	for point in navigation.get_id_path(a,b): result.append(Vector3(point.x,0,point.y))
	return result
