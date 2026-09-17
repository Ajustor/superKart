class_name MarkerField
extends MultiMeshInstance3D

## Repères verticaux dispersés, pour donner une référence de vitesse
## et de distance sur un sol nu.

@export var count: int = 40
@export var field_radius: float = 90.0
@export var inner_radius: float = 12.0
@export var random_seed: int = 1


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 4.0, 1.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.52, 0.22)
	box.material = material

	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = box
	mesh.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in count:
		var angle := rng.randf() * TAU
		# La racine carrée répartit uniformément sur le disque plutôt que
		# de tout tasser au centre.
		var span := field_radius - inner_radius
		var dist := inner_radius + sqrt(rng.randf()) * span
		var pos := Vector3(cos(angle) * dist, 2.0, sin(angle) * dist)
		mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))

	multimesh = mesh
