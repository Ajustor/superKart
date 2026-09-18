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

## Distance de part et d'autre du point courant pour mesurer la courbure.
const CURVATURE_SAMPLE := 10.0

## Fraction de la demi-largeur que la ligne de course peut mordre. En deçà
## de 1.0 pour qu'elle reste sur le bitume et non sur le bord.
const RACING_LINE_BITE := 0.7

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


## Distance le long de l'axe du point de la courbe le plus proche.
func distance_of(point: Vector3) -> float:
	return curve.get_closest_offset(point)


## Écart signé à l'axe, positif à droite de la marche. La composante verticale
## est ignorée : un kart en l'air n'est pas hors-piste.
func lateral_offset(point: Vector3) -> float:
	var d := distance_of(point)
	var vers_point := point - position_at(d)
	vers_point.y = 0.0
	return vers_point.dot(right_at(d))


func is_off_track(point: Vector3) -> bool:
	return absf(lateral_offset(point)) > half_width

## L'axe décalé vers l'intérieur du virage, proportionnellement à la courbure
## locale. Dérivée plutôt que tracée à la main : déplacer un point de contrôle
## déplace la ligne de course avec lui, sans rien à remettre à jour.
func racing_line_at(distance: float) -> Vector3:
	var avant := yaw_at(distance + CURVATURE_SAMPLE)
	var arriere := yaw_at(distance - CURVATURE_SAMPLE)
	# Positif = le circuit tourne à droite ici, donc l'intérieur est à droite.
	var virage := wrapf(avant - arriere, -PI, PI)
	var mordant := clampf(virage / (PI * 0.25), -1.0, 1.0)
	return position_at(distance) + right_at(distance) * mordant * half_width * RACING_LINE_BITE
