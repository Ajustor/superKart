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

## Écart de cap, en degrés, à partir duquel l'IA engage le dérapage.
@export var drift_entry_angle_deg: float = 32.0

## Écart de cap, en degrés, en dessous duquel elle lâche une glisse en cours.
## Plus bas que l'entrée, pour ne pas battre de l'aile à la frontière.
@export var drift_exit_angle_deg: float = 14.0

## Palier de mini-turbo visé avant de lâcher, de 1 à 3. Une IA gourmande tient
## la glisse plus longtemps et sort plus vite — c'est un des quatre leviers de
## difficulté, et le seul qui se voie à l'œil nu.
@export var drift_release_tier: int = 2

## Décalage constant par rapport à la ligne idéale, en mètres vers la droite.
## Une IA qui vise systématiquement à côté pilote mal sans jamais être bridée.
@export var lateral_bias: float = 0.0

## Intervalle entre deux décisions, en secondes. Zéro veut dire une décision
## par image. Au-delà, l'IA tient sa commande précédente : elle braque en
## retard plutôt que mollement, ce qui est la façon dont un humain rate un
## virage.
@export var reaction_delay: float = 0.0

## Renseignés par la session avant chaque image. Les lire soi-même coûterait
## une projection de plus par kart, et global_position interdirait de tester
## cette classe hors de l'arbre.
var track: TrackCurve
var distance: float = 0.0
var position := Vector3.ZERO

var _depuis_decision: float = 0.0
var _steer_decide: float = 0.0
var _drift_decide: bool = false
var _jamais_decide: bool = true


## Le point de mire, sur la ligne de course, devant le kart. Le biais latéral
## s'applique à ce point et non à la distance : viser à côté ne veut pas dire
## viser plus loin.
func point_vise() -> Vector3:
	var avance := maxf(kart.motor.speed * aim_time, aim_minimum)
	var ou := distance + avance
	return track.racing_line_at(ou) + track.right_at(ou) * lateral_bias


func _fill(delta: float) -> void:
	_depuis_decision += delta
	if _jamais_decide or _depuis_decision >= reaction_delay:
		_jamais_decide = false
		_depuis_decision = 0.0
		_steer_decide = _braquage()
		_drift_decide = _veut_deraper()

	command.throttle = 1.0
	command.steer = _steer_decide
	command.drift = _drift_decide


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


## Le dérapage se décide comme le joueur appuie : un booléen, rien de plus.
## Le moteur reste seul juge de ce qu'il en fait.
func _veut_deraper() -> bool:
	if kart.motor.speed < kart.stats.min_drift_speed:
		return false

	var angle := absf(rad_to_deg(ecart_de_cap()))
	if kart.motor.state == KartMotor.State.DRIFT:
		# Une glisse tenue en ligne droite finit dans le décor, et une glisse
		# lâchée trop tôt ne rapporte rien : on sort au premier des deux.
		var palier := kart.motor.tier_for_charge(kart.motor.drift_charge)
		return palier < drift_release_tier and angle > drift_exit_angle_deg

	return angle > drift_entry_angle_deg
