class_name TestGround
extends Node3D

## Garde le kart dans la zone instrumentée et permet de repartir de zéro
## sans relancer le jeu. N'existe que pour la session de validation.

const BOUNDS_RADIUS := 180.0
const FLOOR_LIMIT := -5.0

@export var kart_path: NodePath

var _kart: Kart
var _spawn: Transform3D


func _ready() -> void:
	_kart = get_node(kart_path) as Kart
	assert(_kart != null, "kart_path doit pointer vers un Kart")
	_spawn = _kart.global_transform


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_cancel") or _is_out_of_bounds():
		_kart.respawn_at(_spawn)


func _is_out_of_bounds() -> bool:
	var p := _kart.global_position
	return p.y < FLOOR_LIMIT or Vector2(p.x, p.z).length() > BOUNDS_RADIUS
