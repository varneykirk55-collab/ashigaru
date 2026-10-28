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
static func warrior(parent: Node3D, team: int, asset: PackedScene = null) -> CharacterAnimator:
	var root := CharacterAnimator.new()
	parent.add_child(root)
	root.setup(team,asset)
	return root
