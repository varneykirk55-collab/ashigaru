class_name Geometry
extends RefCounted
static var surface_texture: NoiseTexture2D
static func mat(color: Color, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if metal<0.6:
		if surface_texture==null:
			_make_surface_texture()
		m.albedo_texture=surface_texture
		m.uv1_scale=Vector3(3,3,3)
		m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m
static func _make_surface_texture() -> void:
		var noise := FastNoiseLite.new()
		noise.seed=17; noise.frequency=0.11; noise.fractal_octaves=3
		var texture := NoiseTexture2D.new(); texture.width=128; texture.height=128
		texture.noise=noise
		var gradient := Gradient.new(); gradient.set_color(0,Color(0.42,0.42,0.42)); gradient.set_color(1,Color(0.95,0.95,0.95)); texture.color_ramp=gradient
		surface_texture=texture
static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n
static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var s := BoxMesh.new()
	s.size = size
	var n := mesh(parent,s,pos,material)
	if solid:
		var body := StaticBody3D.new()
		parent.add_child(body)
		body.position = pos
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	return n
static func cylinder(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, material: Material) -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.top_radius=top; s.bottom_radius=bottom; s.height=height; s.radial_segments=20
	return mesh(parent,s,pos,material)
static func sphere(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius=0.5; s.height=1.0
	var n := mesh(parent,s,pos,material)
	n.scale=size
	return n
static func weapon(parent: Node3D, katana: bool) -> Node3D:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	var model: Node3D = load("res://assets/weapons/Katana.glb" if katana else "res://assets/weapons/Flintlock.glb").instantiate()
	pivot.add_child(model)
	model.rotation.y=PI/2
	if katana:
		model.rotation.z=-0.18
		for child in model.find_children("*SCABBARD*", "Node3D", true, false): child.free()
	return pivot
static func warrior(parent: Node3D, team: int) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var cloth := mat(Color("20252a") if team == 1 else Color("353b42"))
	var armor := mat(Color("702f28"),0.55,0.45)
	var trim := mat(Color("b69a60"),0.65,0.4)
	var skin := mat(Color("b18c72"))
	for side in [-1,1]:
		cylinder(root,Vector3(side*0.16,0.47,0),0.13,0.19,0.68,cloth)
		box(root,Vector3(side*0.16,0.1,-0.08),Vector3(0.24,0.17,0.4),cloth)
		var arm := cylinder(root,Vector3(side*0.36,1.18,-0.08),0.11,0.09,0.53,cloth)
		arm.rotation.z=side*0.17
		sphere(root,Vector3(side*0.34,0.98,-0.16),Vector3(0.15,0.2,0.16),skin)
	cylinder(root,Vector3(0,1.12,0),0.28,0.29,0.6,cloth)
	sphere(root,Vector3(0,1.66,0),Vector3(0.32,0.4,0.31),skin)
	cylinder(root,Vector3(0,0.92,0),0.3,0.31,0.1,trim)
	if team == 0:
		for i in range(5):
			box(root,Vector3(0,1.06+i*0.072,-0.24),Vector3(0.49,0.06,0.09),armor)
		for side in [-1,1]:
			for i in range(4):
				box(root,Vector3(side*0.35,1.44-i*0.055,0),Vector3(0.24,0.048,0.36),armor)
			box(root,Vector3(side*0.13,0.77,-0.22),Vector3(0.23,0.25,0.08),armor)
			var horn := cylinder(root,Vector3(side*0.2,1.97,-0.02),0,0.035,0.3,trim)
			horn.rotation.z=-side*0.65
		sphere(root,Vector3(0,1.82,0.025),Vector3(0.4,0.32,0.4),armor)
		cylinder(root,Vector3(0,1.74,0.03),0.22,0.24,0.05,armor)
	else:
		sphere(root,Vector3(0,1.8,0.025),Vector3(0.34,0.2,0.32),cloth)
		var lapel := box(root,Vector3(0,1.31,-0.255),Vector3(0.055,0.34,0.035),mat(Color("777064")))
		lapel.rotation.z=0.5
		cylinder(root,Vector3(0,0.72,0),0.27,0.38,0.42,cloth)
	return root
