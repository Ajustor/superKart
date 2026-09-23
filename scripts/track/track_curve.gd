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

## Variation de cap, sur la fenêtre de mesure, qui vaut une morsure complète.
## Mesuré : un rayon de 10 m sature, un rayon de 50 m mord à moitié.
const FULL_BITE_YAW := PI * 0.25

var curve: Curve3D
var half_width: float
var length: float


## Pas de cuisson de la courbe, en mètres. Godot cuit par défaut tous les
## 20 cm, et get_closest_offset parcourt TOUS les points cuits : 37 µs par
## projection sur le Ruban Céleste, plusieurs fois par kart et par image — un
## gros morceau de la physique sur téléphone. Au mètre, la projection coûte
## cinq fois moins, la longueur du tour bouge d'un millimètre, et la corde
## d'un virage de 25 m de rayon s'écarte de l'arc de 5 mm.
const PAS_DE_CUISSON := 1.0


func _init(track_curve: Curve3D, track_half_width: float) -> void:
	# Une copie : la courbe de la scène reste celle que l'éditeur dessine.
	curve = track_curve.duplicate()
	curve.bake_interval = PAS_DE_CUISSON
	half_width = track_half_width
	length = curve.get_baked_length()
	assert(length > 0.0, "un TrackCurve a besoin d'une courbe de longueur non nulle")


## Ramène une distance quelconque dans [0, length).
func wrap(distance: float) -> float:
	return fposmod(distance, length)


func position_at(distance: float) -> Vector3:
	return curve.sample_baked(self.wrap(distance))


## Tangente complète, pente comprise. C'est la direction dans laquelle la route
## s'en va réellement : sur une descente à 20°, elle pointe 20° vers le bas.
func forward_at(distance: float) -> Vector3:
	var avant := position_at(distance + TANGENT_EPSILON)
	var arriere := position_at(distance - TANGENT_EPSILON)
	var t := avant - arriere
	if t.length_squared() < 0.000001:
		return Vector3.FORWARD
	return t.normalized()


## Tangente à plat, pour tout ce qui raisonne en cap boussole. Dérivée par
## différence finie plutôt que par sample_baked_with_rotation : on ne veut que
## le cap horizontal, et la différence finie ne dépend ni du tilt ni de la
## version de l'API.
func tangent_at(distance: float) -> Vector3:
	var t := forward_at(distance)
	t.y = 0.0
	if t.length_squared() < 0.000001:
		# Route rigoureusement verticale : aucun cap horizontal n'a de sens,
		# mais rendre un vecteur nul contaminerait tout ce qui s'en sert.
		return Vector3.FORWARD
	return t.normalized()


## Dévers demandé à cette distance, en radians, et lui seul.
##
## Godot transporte son propre repère le long d'une courbe 3D, ce qui fait
## rouler le « haut » tout seul dès que la courbe tourne ET monte. Mesuré sur
## le tracé actuel, dont tous les tilts valent zéro : jusqu'à 27° de roulis
## parasite. Une côte n'est pas un virage relevé. On isole donc le dévers en
## comparant le repère avec et sans tilt : leur écart, c'est exactement ce que
## l'auteur du tracé a demandé, et rien d'autre.
func tilt_at(distance: float) -> float:
	var d := self.wrap(distance)
	var sans := curve.sample_baked_up_vector(d, false)
	var avec := curve.sample_baked_up_vector(d, true)
	if sans.length_squared() < 0.000001 or avec.length_squared() < 0.000001:
		return 0.0
	return sans.normalized().signed_angle_to(avec.normalized(), forward_at(d))


## Normale à la chaussée : le « haut » de la route, dévers compris.
##
## Construite à partir de la verticale du monde redressée contre la pente, puis
## tournée du dévers voulu. Sans dévers, une route qui monte garde donc sa
## largeur à l'horizontale ; avec, elle se relève d'exactement ce qu'on a
## demandé à la poignée du Path3D, et pas d'un degré de plus.
func up_at(distance: float) -> Vector3:
	var avant := forward_at(distance)
	var droite := avant.cross(Vector3.UP)
	if droite.length_squared() < 0.000001:
		# Route rigoureusement verticale : aucune horizontale n'a de sens.
		return Vector3.UP
	var haut := droite.normalized().cross(avant).normalized()
	return haut.rotated(avant, tilt_at(distance)).normalized()


## Cap à la boussole : positif vers la droite, comme dans KartMotor.
func yaw_at(distance: float) -> float:
	var t := tangent_at(distance)
	return atan2(t.x, -t.z)


## Le côté droit de la chaussée, dans le plan de la route. Sur une piste plate
## il vaut exactement ce que valait l'ancienne version horizontale ; en pente ou
## en dévers il s'incline avec la route, ce qui est la condition pour que le
## ruban extrudé et la ligne de course restent sur le bitume.
func right_at(distance: float) -> Vector3:
	var droite := forward_at(distance).cross(up_at(distance))
	if droite.length_squared() < 0.000001:
		return Vector3(-tangent_at(distance).z, 0.0, tangent_at(distance).x)
	return droite.normalized()


## Repère complet de la chaussée à cette distance : droite, haut, arrière.
## Godot regarde vers -Z, d'où le dernier axe inversé.
func basis_at(distance: float) -> Basis:
	var avant := forward_at(distance)
	var haut := up_at(distance)
	var droite := avant.cross(haut).normalized()
	return Basis(droite, haut, -avant)


## Pente signée de la route, en radians. Positive quand ça monte.
func slope_at(distance: float) -> float:
	return asin(clampf(forward_at(distance).y, -1.0, 1.0))


## Distance le long de l'axe du point de la courbe le plus proche.
func distance_of(point: Vector3) -> float:
	return curve.get_closest_offset(point)


## Écart signé à l'axe, positif à droite de la marche.
##
## Projeté sur le côté de la CHAUSSÉE et non sur l'horizontale. Un kart en l'air
## n'est toujours pas hors-piste — sa hauteur est portée par la normale, qui est
## perpendiculaire à ce côté, donc elle ne compte pas — mais sur une route en
## dévers, aplatir le vecteur sous-estimait l'écart et laissait le kart déborder
## du bitume sans que rien ne le signale.
func lateral_offset(point: Vector3) -> float:
	return lateral_offset_at(point, distance_of(point))


## La même, quand on connaît déjà la distance du point le long du tracé :
## une projection de moins.
func lateral_offset_at(point: Vector3, distance: float) -> float:
	return (point - position_at(distance)).dot(right_at(distance))


func is_off_track(point: Vector3) -> bool:
	return absf(lateral_offset(point)) > half_width

## Variation de cap sur la fenêtre de mesure, en radians. Positive quand le
## circuit tourne à droite, donc quand l'intérieur du virage est à droite.
##
## Exposée parce que la ligne de course n'est pas seule à vouloir savoir si un
## virage arrive : l'IA en a besoin pour décider de déraper, et elle doit lire
## la même courbure que celle qui a tracé la ligne qu'elle suit.
func turn_at(distance: float) -> float:
	var avant := yaw_at(distance + CURVATURE_SAMPLE)
	var arriere := yaw_at(distance - CURVATURE_SAMPLE)
	return wrapf(avant - arriere, -PI, PI)


## Rayon de courbure approché, en mètres, toujours positif. INF en ligne
## droite. C'est l'arc de la fenêtre de mesure divisé par l'angle balayé :
## la grandeur qu'on compare au rayon de braquage du kart.
func radius_at(distance: float) -> float:
	var virage := absf(turn_at(distance))
	if virage < 0.0001:
		return INF
	return (2.0 * CURVATURE_SAMPLE) / virage


## Rayon local sur une fenêtre courte, celle du pas d'extrusion.
##
## radius_at mesure sur plus ou moins 10 m et lisse donc une cassure ponctuelle ;
## celui-ci la voit. C'est la différence entre un virage serré, qui se négocie,
## et un pli, où le ruban se replie sur lui-même et où le kart s'encastre.
func kink_radius_at(distance: float, step: float = 2.0) -> float:
	var angle := forward_at(distance).angle_to(forward_at(distance + step))
	if angle < 0.0001:
		return INF
	return step / angle


## Les endroits où la route se replie plus court que le rayon donné. Rend des
## couples [distance, rayon], du plus serré au plus large.
func tight_spots(min_radius: float, step: float = 2.0) -> Array:
	var trouves := []
	var d := 0.0
	while d < length:
		var r := kink_radius_at(d, step)
		if r < min_radius:
			trouves.append([d, r])
		d += step
	trouves.sort_custom(func(a, b): return a[1] < b[1])
	return trouves


## L'axe décalé vers l'intérieur du virage, proportionnellement à la courbure
## locale. Dérivée plutôt que tracée à la main : déplacer un point de contrôle
## déplace la ligne de course avec lui, sans rien à remettre à jour.
func racing_line_at(distance: float) -> Vector3:
	var mordant := clampf(turn_at(distance) / FULL_BITE_YAW, -1.0, 1.0)
	return position_at(distance) + right_at(distance) * mordant * half_width * RACING_LINE_BITE
