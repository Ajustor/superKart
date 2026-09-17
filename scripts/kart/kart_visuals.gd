class_name KartVisuals
extends Node3D

## Inclinaison de la caisse et étincelles dont la couleur annonce le palier
## de mini-turbo chargé. Purement cosmétique : ne modifie jamais le moteur.

const TIER_COLORS := [
	Color(0.35, 0.60, 1.00),   # palier 1 — bleu
	Color(1.00, 0.65, 0.14),   # palier 2 — orange
	Color(0.66, 0.33, 0.97),   # palier 3 — violet
]

@export var kart_path: NodePath
@export var body_path: NodePath
@export var sparks_path: NodePath
@export var max_lean_deg: float = 14.0
@export var lean_stiffness: float = 10.0

var _kart: Kart
var _body: Node3D
var _sparks: GPUParticles3D
var _spark_material: StandardMaterial3D


func _ready() -> void:
	_kart = get_node(kart_path) as Kart
	_body = get_node(body_path) as Node3D
	_sparks = get_node(sparks_path) as GPUParticles3D
	assert(_kart != null and _body != null and _sparks != null,
		"KartVisuals a besoin du kart, de la caisse et des particules")

	# Matériau propre à cette instance, sinon tous les karts changeraient
	# de couleur ensemble.
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sparks.material_override = _spark_material
	_sparks.emitting = false


func _process(delta: float) -> void:
	var motor := _kart.motor
	_update_lean(motor, delta)
	_update_sparks(motor)


func _update_lean(motor: KartMotor, delta: float) -> void:
	var lean := 0.0
	if motor.state == KartMotor.State.DRIFT:
		lean = -deg_to_rad(max_lean_deg) * float(motor.drift_dir)
	_body.rotation.z = lerpf(_body.rotation.z, lean, 1.0 - exp(-lean_stiffness * delta))


func _update_sparks(motor: KartMotor) -> void:
	if motor.state != KartMotor.State.DRIFT:
		_sparks.emitting = false
		return

	var tier := motor.tier_for_charge(motor.drift_charge)
	if tier == 0:
		_sparks.emitting = false
		return

	_sparks.emitting = true
	_spark_material.albedo_color = TIER_COLORS[mini(tier, TIER_COLORS.size()) - 1]
