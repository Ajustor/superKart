class_name Kart
extends CharacterBody3D

## Relie la source de commande, le moteur et le déplacement réel.
## Toute la physique horizontale vit dans KartMotor. L'axe vertical
## (saut, gravité, contact au sol) reste ici parce qu'il est couplé à
## move_and_slide() et is_on_floor() — c'est la seule physique non
## couverte par les tests, et elle grossira au plan 2 avec les pentes.

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
	_input.kart = self
	motor.velocity_dir = -rotation.y
	motor.heading = -rotation.y


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

	# Le moteur compte ses angles comme une boussole : lacet positif = vers la
	# droite. Godot compte l'inverse — une rotation positive autour de +Y tourne
	# vers la gauche. La conversion se fait ici, au seul endroit où les deux
	# repères se rencontrent, plutôt que d'éparpiller des signes dans la physique.
	var forward := Vector3(sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))
	velocity = forward * motor.speed + Vector3.UP * _vertical
	move_and_slide()

	rotation.y = -motor.heading


## Remet le kart à un état neutre à la position donnée. Le terrain d'essai
## s'en sert ; la remise en piste du circuit aussi.
func respawn_at(where: Transform3D) -> void:
	global_transform = where
	velocity = Vector3.ZERO
	_vertical = 0.0
	_was_hopping = false
	motor.reset(-where.basis.get_euler().y)
