extends GutTest

## Les bords de piste se franchissent dans les deux sens : sortir vers une
## bande d'herbe, revenir du sol sur la route, rejoindre une bande par son
## bord ou son bout. Ni mur fantôme, ni kart sous la route.
##
## Un anneau de 50 m de rayon, un vrai kart, conduit plein gaz sans braquer.
## Un contact dont la normale pointe à moins de 0,6 vers le haut est un mur :
## c'est le seuil de Kart._encaisser_les_murs.

const DEMI := 9.0

var track: Track
var kart: Kart
var temoin: Temoin


class PleinGaz:
	extends KartInput

	func _fill(_delta: float) -> void:
		command.throttle = 1.0


## Enfant du kart : il passe après lui à chaque image de physique, et compte
## les murs qu'il vient de heurter et son pire enfoncement sous la route.
## Attendre une image depuis le test en laisse passer : GUT en saute.
class Temoin:
	extends Node

	var courbe: TrackCurve
	var contacts := 0
	var sous_la_route := 0.0

	func _physics_process(_delta: float) -> void:
		var k := get_parent() as Kart
		for j in k.get_slide_collision_count():
			if k.get_slide_collision(j).get_normal().y < 0.6:
				contacts += 1
		var p := k.global_position
		var d := courbe.distance_of(p)
		var lateral := courbe.lateral_offset_at(p, d)
		if absf(lateral) < courbe.half_width:
			var route := courbe.position_at(d) + courbe.right_at(d) * lateral
			sous_la_route = maxf(sous_la_route, route.y - p.y)


func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


## Le circuit et ses éléments, montés dans l'arbre.
func _circuit(elements: Array) -> void:
	track = Track.new()
	track.half_width = DEMI
	track.curve = _anneau()
	for e in elements:
		track.add_child(e)
	add_child_autofree(track)


func _bande(decalage: float, largeur: float, debut: float = 60.0, longueur: float = 80.0) -> TrackOffroad:
	var b := TrackOffroad.new()
	b.debut = debut
	b.longueur = longueur
	b.decalage = decalage
	b.largeur = largeur
	return b


func _sol(altitude: float = -0.4) -> TrackSol:
	var s := TrackSol.new()
	s.altitude = altitude
	s.marge = 40.0
	return s


## La hauteur du sol sous ce point, par un rayon vers le bas (masque 1).
func _sol_sous(ici: Vector3) -> Variant:
	var requete := PhysicsRayQueryParameters3D.create(ici + Vector3.UP * 3.0, ici - Vector3.UP * 6.0, 1)
	var touche := track.get_world_3d().direct_space_state.intersect_ray(requete)
	return touche.position.y if not touche.is_empty() else null


## Lance le kart à `distance`, `lateral`, cap tourné de `angle` degrés vers la
## droite du tracé, à `vitesse`, posé sur ce qu'il y a dessous.
func _lancer(distance: float, lateral: float, angle: float, vitesse: float) -> void:
	kart = (load("res://scenes/kart/kart.tscn") as PackedScene).instantiate() as Kart
	add_child_autofree(kart)
	kart.changer_pilote(PleinGaz.new())
	var c := track.track_curve
	await wait_physics_frames(2)
	var ici := TrackFeature.point(c, distance, lateral, 0.0)
	var sol: Variant = _sol_sous(ici)
	if sol != null:
		ici.y = sol
	var avant := c.forward_at(distance)
	avant.y = 0.0
	var droite := c.right_at(distance)
	droite.y = 0.0
	var cap := (avant.normalized() * cos(deg_to_rad(angle)) + droite.normalized() * sin(deg_to_rad(angle))).normalized()
	kart.respawn_at(Transform3D(Basis.looking_at(cap, Vector3.UP), ici + Vector3.UP * 0.05))
	kart.motor.speed = vitesse
	temoin = Temoin.new()
	temoin.courbe = c
	kart.add_child(temoin)


func _rouler(duree: float) -> void:
	await wait_seconds(duree)


## Sur la bande, au ras du bord de la route : pas passé dessous.
func _assert_dessus() -> void:
	assert_gt(kart.global_position.y, -0.1, "sur la bande, pas dessous (hauteur %.2f)" % kart.global_position.y)


func _lateral() -> float:
	return track.track_curve.lateral_offset(kart.global_position)


func test_sortir_vers_une_bande_d_herbe_ne_heurte_rien() -> void:
	_circuit([_bande(DEMI + 6.0, 12.0)])
	await _lancer(100.0, DEMI - 2.5, 35.0, 15.0)
	await _rouler(1.5)
	assert_gt(_lateral(), DEMI + 1.5, "le kart est sur la bande (latéral %.2f)" % _lateral())
	assert_eq(temoin.contacts, 0, "aucun mur au bord de la bande")


func test_revenir_du_sol_sur_la_route() -> void:
	_circuit([_sol()])
	await _lancer(100.0, DEMI + 4.0, -35.0, 12.0)
	# Assez pour monter sur la route, pas pour la traverser.
	await _rouler(1.2)
	assert_lt(absf(_lateral()), DEMI - 1.0, "revenu sur la route (latéral %.2f)" % _lateral())
	var c := track.track_curve
	var d := c.distance_of(kart.global_position)
	var route := c.position_at(d) + c.right_at(d) * _lateral()
	assert_almost_eq(kart.global_position.y, route.y, 0.05, "sur la chaussée, pas dessous")
	assert_eq(temoin.contacts, 0, "aucun mur au bord de la route")


func test_le_kart_ne_passe_jamais_sous_la_route() -> void:
	_circuit([_sol()])
	await _lancer(100.0, DEMI + 4.0, -35.0, 12.0)
	await _rouler(2.5)
	assert_lt(temoin.sous_la_route, 0.05, "enfoncé de %.2f m sous la route" % temoin.sous_la_route)


func test_pas_de_talus_au_dessus_du_vide() -> void:
	_circuit([])
	await wait_physics_frames(2)
	var c := track.track_curve
	for d in [20.0, 100.0, 200.0]:
		for cote in [-1.0, 1.0]:
			var ici := TrackFeature.point(c, d, cote * (DEMI + 2.0), 0.0)
			assert_null(_sol_sous(ici), "rien sous le bord à %.0f m (côté %+.0f)" % [d, cote])


func test_rejoindre_une_bande_depuis_le_sol() -> void:
	_circuit([_sol(), _bande(DEMI + 3.5, 7.0)])
	await _lancer(100.0, DEMI + 10.0, -35.0, 12.0)
	await _rouler(0.8)
	assert_lt(_lateral(), DEMI + 6.0, "le kart est monté sur la bande (latéral %.2f)" % _lateral())
	_assert_dessus()
	assert_eq(temoin.contacts, 0, "aucun mur au bord extérieur de la bande")


func test_entrer_dans_une_bande_par_son_bout() -> void:
	_circuit([_sol(), _bande(DEMI + 8.0, 6.0, 100.0, 40.0)])
	await _lancer(92.0, DEMI + 8.0, 0.0, 12.0)
	await _rouler(1.5)
	var c := track.track_curve
	assert_gt(c.distance_of(kart.global_position), 104.0, "le kart est entré dans la bande")
	_assert_dessus()
	assert_eq(temoin.contacts, 0, "aucun mur au bout de la bande")
