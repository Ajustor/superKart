class_name AIInput
extends KartInput

## Pilote automatique. Elle vise un point de la ligne de course situé à une
## demi-seconde de trajet devant elle, mesure l'écart entre son cap et la
## direction de ce point, et en tire un braquage.
##
## Elle passe par le même KartCommand que le joueur, donc elle est enfermée
## dans la même physique : elle ne peut pas prendre un virage que le joueur ne
## pourrait pas prendre, et elle dérape pour de vrai, avec les mêmes étincelles.
##
## Tous les angles sont des caps boussole — positif vers la droite — comme dans
## KartMotor et TrackCurve. Aucune rotation Godot n'apparaît ici.

## Durée de trajet qui sépare le kart de son point de mire. Plus elle est
## grande, plus l'IA anticipe et plus ses trajectoires sont propres.
@export var aim_time: float = 0.45

## Distance de mire minimale, en mètres. Sans elle, un kart à l'arrêt viserait
## ses propres roues et ne démarrerait jamais.
@export var aim_minimum: float = 6.0

## Écart de cap, en degrés, au-delà duquel l'IA braque à fond.
@export var full_steer_angle_deg: float = 20.0

## Renseignés par la session avant chaque image. Les lire soi-même coûterait
## une projection de plus par kart, et global_position interdirait de tester
## cette classe hors de l'arbre.
var track: TrackCurve
var distance: float = 0.0
var position := Vector3.ZERO


## Le point de mire, sur la ligne de course, devant le kart.
func point_vise() -> Vector3:
	var avance := maxf(kart.motor.speed * aim_time, aim_minimum)
	return track.racing_line_at(distance + avance)


func _fill(_delta: float) -> void:
	command.throttle = 1.0
	command.steer = _braquage()


## Écart de cap entre la direction du kart et celle du point de mire, en
## radians, ramené dans [-PI, PI]. Positif = la cible est à droite.
func ecart_de_cap() -> float:
	var vers := point_vise() - position
	vers.y = 0.0
	if vers.length_squared() < 0.0001:
		return 0.0
	var cap_voulu := atan2(vers.x, -vers.z)
	return wrapf(cap_voulu - kart.motor.heading, -PI, PI)


func _braquage() -> float:
	var plein := deg_to_rad(full_steer_angle_deg)
	return clampf(ecart_de_cap() / plein, -1.0, 1.0)
