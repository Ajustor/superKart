class_name Kart
extends CharacterBody3D

## Relie la source de commande, le moteur et le déplacement réel.
## Ne contient aucune règle de pilotage : tout est dans KartMotor.

@export var stats: KartStats
@export var input_path: NodePath

var motor: KartMotor

var _input: KartInput
var _vertical: float = 0.0
var _was_hopping: bool = false


func _ready() -> void:
	assert(stats != null, "un Kart doit avoir une ressource KartStats")
	motor = KartMotor.new(stats)
	_input = get_node(input_path) as KartInput
	assert(_input != null, "input_path doit pointer vers un KartInput")
	motor.velocity_dir = rotation.y
	motor.heading = rotation.y


func _physics_process(delta: float) -> void:
	var cmd := _input.poll(delta)
	motor.step(cmd, delta)

	# Le saut d'entrée en dérapage, purement vertical.
	var hopping := motor.state == KartMotor.State.HOP
	if hopping and not _was_hopping:
		_vertical = stats.hop_impulse
	_was_hopping = hopping

	if is_on_floor() and _vertical <= 0.0:
		_vertical = 0.0
	else:
		_vertical -= stats.gravity * delta

	# En Godot, l'avant d'un nœud 3D est -Z.
	var forward := Vector3(-sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))
	velocity = forward * motor.speed + Vector3.UP * _vertical
	move_and_slide()

	rotation.y = motor.heading
