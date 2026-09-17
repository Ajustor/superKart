class_name KartCommand
extends RefCounted

## Intention d'un pilote pour une frame. Produite par KartInput,
## consommée par KartMotor. Une seule instance par kart, réutilisée
## à chaque frame pour ne rien allouer dans _physics_process.

var steer: float = 0.0      ## -1.0 (gauche) .. 1.0 (droite)
var throttle: float = 0.0   ##  0.0 .. 1.0
var brake: float = 0.0      ##  0.0 .. 1.0
var drift: bool = false
var use_item: bool = false


func clear() -> void:
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	drift = false
	use_item = false
