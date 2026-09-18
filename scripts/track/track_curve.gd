class_name TrackCurve
extends RefCounted

## Enrobe le Curve3D qui définit l'axe d'un circuit et en dérive tout ce dont
## la course a besoin. Comme KartMotor, cette classe ne connaît ni la scène ni
## les nœuds : elle ne fait que du calcul sur une courbe, et se teste donc
## entièrement sans lancer le moteur de rendu.
##
## Les caps qu'elle produit suivent la convention du moteur — lacet positif
## vers la droite — pour se comparer directement à motor.heading.
##
## La courbe est supposée fermée : les distances s'enroulent modulo la
## longueur. Sur une courbe ouverte, la tangente près des extrémités
## échantillonnerait l'autre bout et renverrait une direction sans rapport.

## Écart utilisé pour dériver la tangente par différence finie, en mètres.
const TANGENT_EPSILON := 0.25

var curve: Curve3D
var half_width: float
var length: float


func _init(track_curve: Curve3D, track_half_width: float) -> void:
	curve = track_curve
	half_width = track_half_width
	length = curve.get_baked_length()
	assert(length > 0.0, "un TrackCurve a besoin d'une courbe de longueur non nulle")


## Ramène une distance quelconque dans [0, length).
func wrap(distance: float) -> float:
	return fposmod(distance, length)


func position_at(distance: float) -> Vector3:
	return curve.sample_baked(self.wrap(distance))


## Dérivée par différence finie plutôt que par sample_baked_with_rotation :
## on ne veut que le cap horizontal, et la différence finie ne dépend pas
## du tilt ni de la version de l'API.
func tangent_at(distance: float) -> Vector3:
	var avant := position_at(distance + TANGENT_EPSILON)
	var arriere := position_at(distance - TANGENT_EPSILON)
	var t := avant - arriere
	t.y = 0.0
	return t.normalized()


## Cap à la boussole : positif vers la droite, comme dans KartMotor.
func yaw_at(distance: float) -> float:
	var t := tangent_at(distance)
	return atan2(t.x, -t.z)


func right_at(distance: float) -> Vector3:
	var t := tangent_at(distance)
	return Vector3(-t.z, 0.0, t.x)
